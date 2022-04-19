const std = @import("std");
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});

const Demo = @import("demo.zig");

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
    const allocator = gpa.allocator();

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
    window = c.glfwCreateWindow(@floatToInt(i32, scale * 1000), @floatToInt(i32, scale * 600), "NanoVG", null, null);
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

    var demo: Demo = undefined;
    demo.load(vg);
    defer demo.free(vg);

    c.glfwSwapInterval(0);

    c.glfwSetTime(0);
    prevt = c.glfwGetTime();

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        const t = c.glfwGetTime();
        const dt = t - prevt;
        prevt = t;

        var mx: f64 = undefined;
        var my: f64 = undefined;
        c.glfwGetCursorPos(window, &mx, &my);
        mx /= scale;
        my /= scale;
        var winWidth: i32 = undefined;
        var winHeight: i32 = undefined;
        c.glfwGetWindowSize(window, &winWidth, &winHeight);
        winWidth = @floatToInt(i32, @intToFloat(f32, winWidth) / scale);
        winHeight = @floatToInt(i32, @intToFloat(f32, winHeight) / scale);
        var fbWidth: i32 = undefined;
        var fbHeight: i32 = undefined;
        c.glfwGetFramebufferSize(window, &fbWidth, &fbHeight);

        // Calculate pixel ratio for hi-dpi devices.
        const pxRatio = @intToFloat(f32, fbWidth) / @intToFloat(f32, winWidth);

        // Update and render
        c.glViewport(0, 0, fbWidth, fbHeight);
        if (premult) {
            c.glClearColor(0, 0, 0, 0);
        } else {
            c.glClearColor(0.3, 0.3, 0.32, 1.0);
        }
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

        _ = dt;
        vg.beginFrame(@intToFloat(f32, winWidth), @intToFloat(f32, winHeight), pxRatio);

        demo.draw(vg, @floatCast(f32, mx), @floatCast(f32, my), @intToFloat(f32, winWidth), @intToFloat(f32, winHeight), @floatCast(f32, t), blowup);

        vg.endFrame();

        if (screenshot) {
            screenshot = false;
            const data = try Demo.saveScreenshot(allocator, fbWidth, fbHeight, premult);
            defer allocator.free(data);
            try std.fs.cwd().writeFile("dump.png", data);
        }

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
