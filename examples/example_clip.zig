const std = @import("std");
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});

const nvg = @import("nanovg");

fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    _ = scancode;
    _ = mods;
    if (key == c.GLFW_KEY_ESCAPE and action == c.GLFW_PRESS)
        c.glfwSetWindowShouldClose(window, c.GL_TRUE);
}

fn pathStar(vg: nvg, x: f32, y: f32, n: usize, inr: f32, outr: f32) void {
    const to_angle = 2 * std.math.pi / @as(f32, @floatFromInt(n));
    for (0..n) |i| {
        const fi: f32 = @floatFromInt(i);
        const a0 = fi * to_angle;
        const a1 = (fi + 0.5) * to_angle;
        if (i == 0)
            vg.moveTo(x + outr * @sin(a0), y - outr * @cos(a0))
        else
            vg.lineTo(x + outr * @sin(a0), y - outr * @cos(a0));
        vg.lineTo(x + inr * @sin(a1), y - inr * @cos(a1));
    }
    vg.closePath();
}

pub fn main() !void {
    var window: ?*c.GLFWwindow = null;
    var prevt: f64 = 0;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

    if (c.glfwInit() == c.GLFW_FALSE) {
        return error.GLFWInitFailed;
    }
    defer c.glfwTerminate();
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 2);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 0);

    const monitor = c.glfwGetPrimaryMonitor();
    var scale: f32 = 1;
    if (!builtin.target.isDarwin()) {
        c.glfwGetMonitorContentScale(monitor, &scale, null);
    }
    window = c.glfwCreateWindow(@as(i32, @intFromFloat(scale * 1000)), @as(i32, @intFromFloat(scale * 600)), "NanoVG", null, null);
    if (window == null) {
        return error.GLFWInitFailed;
    }
    defer c.glfwDestroyWindow(window);

    _ = c.glfwSetKeyCallback(window, keyCallback);

    c.glfwMakeContextCurrent(window);

    if (c.gladLoadGL() == 0) {
        return error.GLADInitFailed;
    }

    var vg = try nvg.gl.init(allocator, .{
        .antialias = true,
        .stencil_strokes = false,
        .debug = true,
    });
    defer vg.deinit();

    c.glfwSwapInterval(0);

    c.glfwSetTime(0);
    prevt = c.glfwGetTime();

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        const t = c.glfwGetTime();
        const dt = t - prevt;
        prevt = t;
        _ = dt;

        var mx: f64 = undefined;
        var my: f64 = undefined;
        c.glfwGetCursorPos(window, &mx, &my);
        mx /= scale;
        my /= scale;
        var win_width: i32 = undefined;
        var win_height: i32 = undefined;
        c.glfwGetWindowSize(window, &win_width, &win_height);
        win_width = @intFromFloat(@as(f32, @floatFromInt(win_width)) / scale);
        win_height = @intFromFloat(@as(f32, @floatFromInt(win_height)) / scale);
        var fb_width: i32 = undefined;
        var fb_height: i32 = undefined;
        c.glfwGetFramebufferSize(window, &fb_width, &fb_height);

        // Calculate pixel ratio for hi-dpi devices.
        const pxRatio = @as(f32, @floatFromInt(fb_width)) / @as(f32, @floatFromInt(win_width));

        // Update and render
        c.glViewport(0, 0, fb_width, fb_height);
        c.glClearColor(0.3, 0.3, 0.32, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

        vg.beginFrame(@floatFromInt(win_width), @floatFromInt(win_height), pxRatio);

        vg.beginPath();
        // vg.setClipPath();
        vg.addPath(.{
            .verbs = &.{ .move, .line, .line, .line, .close },
            .points = &.{ 50, 50, 150, 50, 150, 150, 50, 150 },
        });
        vg.fillColor(nvg.rgbaf(1, 0, 0, 0.5));
        vg.fill();

        vg.beginPath();
        vg.translate(100, 100);
        vg.rotate(@floatCast(t));
        pathStar(vg, 0, 0, 5, 35, 80);
        vg.fillColor(nvg.rgbaf(1, 1, 0, 0.5));
        vg.fill();
        vg.resetTransform();

        // donut
        vg.beginPath();
        vg.circle(250, 100, 50);
        vg.pathWinding(.cw);
        vg.circle(250, 100, 20);
        vg.fillColor(nvg.rgbaf(1, 0.5, 0, 0.5));
        vg.fill();

        // heart
        vg.translate(300, 0);
        vg.scale(4, 4);
        vg.beginPath();
        const half_heart = nvg.Path{
            .verbs = &.{ .move, .bezier, .bezier, .bezier },
            .points = &.{ 25, 38, 20, 34, 9, 27, 9, 19, 9, 14.5, 12.5, 11, 17, 11, 20, 11, 23, 12, 25, 15.5 },
        };
        vg.addPath(half_heart);
        vg.translate(50, 0);
        vg.scale(-1, 1);
        vg.addPath(half_heart);
        vg.fillColor(nvg.rgbf(1, 0, 0));
        vg.fill();
        vg.resetTransform();

        const twitter = nvg.Path{
            .verbs = &.{ .move, .bezier, .bezier, .bezier, .bezier, .bezier, .bezier, .bezier, .bezier, .bezier, .bezier, .bezier, .bezier, .bezier, .bezier, .bezier, .bezier, .bezier },
            // zig fmt: off
            .points = &.{
                221.95,51.29,
                222.1,53.46, 222.1,55.63, 222.1,57.82,
                222.1,124.55, 171.3,201.51, 78.41,201.51,
                50.97,201.51, 24.1,193.65, 1,178.83, 
                4.99,179.31, 9,179.55, 13.02,179.56,
                35.76,179.58, 57.85,171.95, 75.74,157.9,
                54.13,157.49, 35.18,143.4, 28.56,122.83,
                36.13,124.29, 43.93,123.99, 51.36,121.96,
                27.8,117.2, 10.85,96.5, 10.85,72.46,
                17.87,75.73, 25.73,77.9, 33.77,78.14,
                11.58,63.31, 4.74,33.79, 18.14,10.71,
                43.78,42.26, 81.61,61.44, 122.22,63.47,
                118.15,45.93, 123.71,27.55, 136.83,15.22,
                157.17,-3.9, 189.16,-2.92, 208.28,17.41,
                219.59,15.18, 230.43,11.03, 240.35,5.15,
                236.58,16.84, 228.69,26.77, 218.15,33.08,
                228.16,31.9, 237.94,29.22, 247.15,25.13,
                240.37,35.29 ,231.83,44.14, 221.95,51.29,
            },
            // zig fmt: on
        };
        vg.translate(500, 50);
        vg.scale(0.5, 0.5);
        vg.beginPath();
        vg.addPath(twitter);
        vg.fillColor(nvg.rgb(0x1D, 0x9B, 0xF0));
        vg.fill();

        vg.endFrame();

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
