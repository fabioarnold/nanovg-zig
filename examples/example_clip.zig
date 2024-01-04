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

fn scaleToFit(vg: nvg, w: f32, h: f32, target_w: f32, target_h: f32) void {
    const sx = target_w / w;
    const sy = target_h / h;
    const s = @min(sx, sy);
    vg.translate(0.5 * target_w, 0.5 * target_h);
    vg.scale(s, s);
    vg.translate(-0.5 * w, -0.5 * h);
}

fn pathStar(vg: nvg, n: usize, inr: f32, outr: f32) void {
    const to_angle = 2 * std.math.pi / @as(f32, @floatFromInt(n));
    for (0..n) |i| {
        const fi: f32 = @floatFromInt(i);
        const a0 = fi * to_angle;
        const a1 = (fi + 0.5) * to_angle;
        if (i == 0)
            vg.moveTo(outr * @sin(a0), -outr * @cos(a0))
        else
            vg.lineTo(outr * @sin(a0), -outr * @cos(a0));
        vg.lineTo(inr * @sin(a1), -inr * @cos(a1));
    }
    vg.closePath();
}

fn pathDonut(vg: nvg, r: f32) void {
    vg.circle(0, 0, r);
    vg.pathWinding(.cw);
    vg.circle(0, 0, 0.4 * r);
}

fn pathHeart(vg: nvg, w: f32, h: f32) void {
    vg.save();
    defer vg.restore();

    const min_x = 9;
    const min_y = 11;
    const max_x = 41;
    const max_y = 38;
    scaleToFit(vg, max_x - min_x, max_y - min_y, w, h);
    vg.translate(-min_x, -min_y);
    const heart = nvg.Path{
        .verbs = &.{ .move, .bezier, .bezier, .bezier, .bezier, .bezier, .bezier },
        .points = &.{ 25, 38, 20, 34, 9, 27, 9, 19, 9, 14.5, 12.5, 11, 17, 11, 20, 11, 23, 12, 25, 15.5, 27, 12, 30, 11, 33, 11, 37.5, 11, 41, 14.5, 41, 19, 41, 27, 30, 34, 25, 38 },
    };
    vg.addPath(heart);
}

fn pathTwitterLogo(vg: nvg, w: f32, h: f32) void {
    vg.save();
    defer vg.restore();

    scaleToFit(vg, 248, 204, w, h);

    // const width = 248;
    // const height = 204;
    const twitter_logo = nvg.Path{
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
    vg.addPath(twitter_logo);
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
    c.glfwWindowHint(c.GLFW_SAMPLES, 4);

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
        .debug = true,
    });
    defer vg.deinit();

    c.glfwSwapInterval(0);

    c.glfwSetTime(0);
    prevt = c.glfwGetTime();

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        const t = c.glfwGetTime();
        const t32: f32 = @floatCast(t);
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

        if (false) {
            vg.beginPath();
            vg.addPath(.{
                .verbs = &.{ .move, .line, .line, .line, .close },
                .points = &.{ 50, 50, 150, 50, 150, 150, 50, 150 },
            });
            vg.fillColor(nvg.rgbaf(1, 0, 0, 0.5));
            vg.fill();

            vg.beginPath();
            vg.translate(100, 100);
            vg.rotate(t32);
            pathStar(vg, 5, 35, 80);
            vg.resetTransform();
            vg.fillColor(nvg.rgbaf(1, 1, 0, 0.5));
            vg.fill();

            // donut
            vg.beginPath();
            vg.translate(250, 100);
            pathDonut(vg, 50);
            vg.resetTransform();
            vg.fillColor(nvg.rgbaf(1, 0.5, 0, 0.5));
            vg.fill();

            // heart
            vg.beginPath();
            vg.translate(350, 50);
            pathHeart(vg, 100, 100);
            vg.resetTransform();
            vg.fillColor(nvg.rgbf(1, 0, 0));
            vg.fill();

            // twitter logo
            vg.beginPath();
            vg.translate(500, 50);
            pathTwitterLogo(vg, 100, 100);
            vg.resetTransform();
            vg.fillColor(nvg.rgb(0x1D, 0x9B, 0xF0));
            vg.fill();

            vg.beginPath();
            vg.translate(200, 200);
            pathTwitterLogo(vg, 200, 200);
            vg.clip();
            vg.translate(100, 100);
            pathDonut(vg, 100);
            vg.strokeColor(nvg.rgb(0, 0, 0));
            vg.strokeWidth(4);
            vg.stroke();
            vg.fill();
        } else {
            vg.translate(500, 300);
            vg.beginPath();
            vg.save();
            vg.translate(-120, -120);
            pathHeart(vg, 240, 240);
            vg.restore();
            vg.strokeColor(nvg.rgb(0, 0, 0));
            vg.strokeWidth(8);
            vg.stroke();
            vg.fillColor(nvg.rgbf(1, 0, 0));
            vg.fill();

            vg.beginPath();
            vg.translate(-120, -120);
            pathHeart(vg, 240, 240);
            vg.translate(120, 120);
            // vg.rect(-100, -100, 200, 200); // convex clip
            vg.clip();
            vg.rotate(t32);
            vg.translate(-100, -100);
            pathTwitterLogo(vg, 200, 200);
            vg.fillColor(nvg.rgb(0x1D, 0x9B, 0xF0));
            vg.fill();
        }

        vg.endFrame();

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
