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

    var fb: [2]Framebuffer = undefined;
    fb[0] = Framebuffer.create(vg, 64, 64, .{});
    fb[1] = Framebuffer.create(vg, 64, 64, .{});
    defer fb[0].delete(vg);
    defer fb[1].delete(vg);

    var fps = PerfGraph.init(.fps, "Frame Time");

    _ = vg.createFontMem("sans", @embedFile("Roboto-Regular.ttf"));
    const image_baboon = vg.createImageMem(@embedFile("images/baboon.jpg"), .{
        .generate_mipmaps = true,
        .repeat_x = false,
        .repeat_y = false,
        .premultiplied = true,
    });

    c.glfwSwapInterval(1);

    c.glfwSetTime(0);
    var prevt = c.glfwGetTime();

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        const t = c.glfwGetTime();
        const dt = t - prevt;
        prevt = t;
        fps.update(@floatCast(dt));

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

        // blur x
        fb[0].bind();
        c.glViewport(0, 0, 64, 64);
        vg.beginFrame(64, 64, 1);
        vg.beginPath();
        vg.rect(0, 0, 64, 64);
        vg.fillPaint(vg.imageBlur(64, 64, image_baboon, 1.0, 0));
        vg.fill();
        vg.endFrame();
        // blur y
        fb[1].bind();
        c.glViewport(0, 0, 64, 64);
        vg.beginFrame(64, 64, 1);
        vg.beginPath();
        vg.rect(0, 0, 64, 64);
        vg.fillPaint(vg.imageBlur(64, 64, fb[0].image, 0, 1.0));
        vg.fill();
        vg.endFrame();
        Framebuffer.unbind();

        // Update and render
        c.glViewport(0, 0, fb_width, fb_height);
        c.glClearColor(0.3, 0.3, 0.32, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

        vg.beginFrame(@floatFromInt(win_width), @floatFromInt(win_height), pxRatio);

        {
            vg.save();
            defer vg.restore();

            var x: f32 = (@as(f32, @floatFromInt(win_width)) - 512) / 3;
            const y: f32 = (@as(f32, @floatFromInt(win_height)) - 256) / 2;

            vg.beginPath();
            vg.rect(x, y, 256, 256);
            vg.fillPaint(vg.imagePattern(x, y, 256, 256, 0, image_baboon, 1));
            vg.fill();

            vg.fontFace("sans");
            vg.fillColor(nvg.rgbf(1, 1, 1));
            _ = vg.text(x, y, "Normal");

            x = 2 * x + 256;
            vg.beginPath();
            vg.rect(x, y, 256, 256);
            vg.fillPaint(vg.imagePattern(x, y, 256, 256, 0, fb[1].image, 1));
            vg.fill();

            vg.fillColor(nvg.rgbf(1, 1, 1));
            _ = vg.text(x, y, "Blur 8px");
        }

        fps.draw(vg, 5, 5);

        vg.endFrame();

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
