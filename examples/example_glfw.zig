const std = @import("std");
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});

const Demo = @import("demo.zig");
const PerfGraph = @import("perf.zig");

const nvg = @import("nanovg");

var blowup: bool = false;
var screenshot: bool = false;
var premult: bool = false;

fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    _ = scancode;
    _ = mods;
    if (key == c.GLFW_KEY_ESCAPE and action == c.GLFW_PRESS)
        c.glfwSetWindowShouldClose(window, c.GL_TRUE);
    if (key == c.GLFW_KEY_SPACE and action == c.GLFW_PRESS)
        blowup = !blowup;
    if (key == c.GLFW_KEY_S and action == c.GLFW_PRESS)
        screenshot = true;
    if (key == c.GLFW_KEY_P and action == c.GLFW_PRESS)
        premult = !premult;
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

    var demo: Demo = undefined;
    demo.load(vg);
    defer demo.free(vg);
    var fps = PerfGraph.init(.fps, "Frame Time");

    c.glfwSwapInterval(0);

    c.glfwSetTime(0);
    prevt = c.glfwGetTime();

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

        // Update and render
        c.glViewport(0, 0, fb_width, fb_height);
        if (premult) {
            c.glClearColor(0, 0, 0, 0);
        } else {
            c.glClearColor(0.3, 0.3, 0.32, 1.0);
        }
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

        vg.beginFrame(@floatFromInt(win_width), @floatFromInt(win_height), pxRatio);

        demo.draw(vg, @floatCast(mx), @floatCast(my), @floatFromInt(win_width), @floatFromInt(win_height), @floatCast(t), blowup);
        fps.draw(vg, 5, 5);

        vg.endFrame();

        if (screenshot) {
            screenshot = false;
            const data = try Demo.saveScreenshot(allocator, fb_width, fb_height, premult);
            defer allocator.free(data);
            try std.fs.cwd().writeFile(.{ .sub_path = "dump.png", .data = data });
        }

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
