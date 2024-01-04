const std = @import("std");
const builtin = @import("builtin");
const nvg = @import("nanovg");
const Framebuffer = nvg.gl.Framebuffer;
const gl = nvg.gl.gl;

const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});

const PerfGraph = @import("perf.zig");

fn renderPattern(vg: nvg, fb: Framebuffer, t: f32, pxRatio: f32) void {
    const s = 20;
    const sr = (@cos(t) + 1) * 0.5;
    const r = s * 0.6 * (0.2 + 0.8 * sr);

    var fbo_width: u32 = undefined;
    var fbo_height: u32 = undefined;
    vg.imageSize(fb.image, &fbo_width, &fbo_height);
    const win_width: f32 = @as(f32, @floatFromInt(fbo_width)) / pxRatio;
    const win_height: f32 = @as(f32, @floatFromInt(fbo_height)) / pxRatio;

    // Draw some stuff to an FBO as a test
    fb.bind();
    gl.glViewport(0, 0, @intCast(fbo_width), @intCast(fbo_height));
    gl.glClearColor(0, 0, 0, 0);
    gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_STENCIL_BUFFER_BIT);
    vg.beginFrame(win_width, win_height, pxRatio);

    const pw: u32 = @intFromFloat(std.math.ceil(win_width / s));
    const ph: u32 = @intFromFloat(std.math.ceil(win_height / s));

    vg.beginPath();
    for (0..ph) |y| {
        for (0..pw) |x| {
            const cx: f32 = (@as(f32, @floatFromInt(x)) + 0.5) * s;
            const cy: f32 = (@as(f32, @floatFromInt(y)) + 0.5) * s;
            vg.circle(cx, cy, r);
        }
    }
    vg.fillColor(nvg.rgba(220, 160, 0, 200));
    vg.fill();

    vg.endFrame();
    Framebuffer.unbind();
}

fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    _ = scancode;
    _ = mods;
    if (key == c.GLFW_KEY_ESCAPE and action == c.GLFW_PRESS)
        c.glfwSetWindowShouldClose(window, c.GL_TRUE);
}

pub fn main() !void {
    var window: ?*c.GLFWwindow = null;

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

    // The image pattern is tiled, set repeat on x and y.
    var fb = Framebuffer.create(vg, @intFromFloat(100 * pxRatio), @intFromFloat(100 * pxRatio), .{ .repeat_x = true, .repeat_y = true });
    defer fb.delete(vg);

    c.glfwSwapInterval(0);

    // initGPUTimer(&gpuTimer);

    c.glfwSetTime(0);
    var prevt = c.glfwGetTime();

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        const t = c.glfwGetTime();
        const dt = t - prevt;
        _ = dt;
        prevt = t;
        const t32: f32 = @floatCast(t);

        // startGPUTimer(&gpuTimer);

        var mx: f64 = undefined;
        var my: f64 = undefined;
        c.glfwGetCursorPos(window, &mx, &my);
        mx /= scale;
        my /= scale;
        c.glfwGetWindowSize(window, &win_width, &win_height);
        win_width = @intFromFloat(@as(f32, @floatFromInt(win_width)) / scale);
        win_height = @intFromFloat(@as(f32, @floatFromInt(win_height)) / scale);
        c.glfwGetFramebufferSize(window, &fb_width, &fb_height);

        renderPattern(vg, fb, t32, pxRatio);

        // Update and render
        c.glViewport(0, 0, fb_width, fb_height);
        c.glClearColor(0.3, 0.3, 0.32, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

        vg.beginFrame(@floatFromInt(win_width), @floatFromInt(win_height), pxRatio);

        {
            // Use the FBO as image pattern.
            const img = vg.imagePattern(0, 0, 100, 100, 0, fb.image, 1);
            vg.save();
            defer vg.restore();

            for (0..20) |i| {
                const fi: f32 = @floatFromInt(i);
                vg.beginPath();
                vg.rect(10 + fi * 30, 10, 10, @floatFromInt(win_height - 20));
                vg.fillColor(nvg.hsla(fi / 19.0, 0.5, 0.5, 255));
                vg.fill();
            }

            vg.beginPath();
            vg.roundedRect(140 + @sin(t32 * 1.3) * 100, 140 + @cos(t32 * 1.71244) * 100, 250, 250, 20);
            vg.fillPaint(img);
            vg.fill();
            vg.strokeColor(nvg.rgba(220, 160, 0, 255));
            vg.strokeWidth(3);
            vg.stroke();
        }

        vg.endFrame();

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
