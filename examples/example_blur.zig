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

fn drawSlider(vg: nvg, x: f32, y: f32, w: f32, value: f32) void {
    vg.fillColor(nvg.rgb(0xdd, 0xdd, 0xdd));
    vg.strokeColor(nvg.rgb(0x55, 0x55, 0x55));
    vg.beginPath();
    vg.roundedRect(x - 2.5, y - 2.5, w + 5, 5, 2.5);
    vg.fill();
    vg.stroke();
    const knob_x = x + @round(w * value);
    vg.beginPath();
    vg.ellipse(knob_x, y, 6.5, 6.6);
    vg.fill();
    vg.stroke();
}

fn pointInRect(px: f32, py: f32, rx: f32, ry: f32, rw: f32, rh: f32) bool {
    return px >= rx and py >= ry and px < rx + rw and py < ry + rh;
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

    var fb_x: [9]Framebuffer = undefined;
    var fb_y: [9]Framebuffer = undefined;
    for (0..fb_x.len) |i| {
        const w = @as(u32, 256) >> @as(u5, @intCast(i));
        fb_x[i] = Framebuffer.create(vg, w, w, .{});
        fb_y[i] = Framebuffer.create(vg, w, w, .{});
    }

    var blur: f32 = 8;
    const blur_max: f32 = 256;
    var slider_value: f32 = 0.375;
    var slider_grab: bool = false;

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
    var mouse_down_prev = false;

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        const t = c.glfwGetTime();
        const dt = t - prevt;
        prevt = t;
        fps.update(@floatCast(dt));

        var mx: f64 = undefined;
        var my: f64 = undefined;
        c.glfwGetCursorPos(window, &mx, &my);
        const mouse_x: f32 = @floatCast(@round(mx));
        const mouse_y: f32 = @floatCast(@round(my));
        const mouse_down = c.glfwGetMouseButton(window, 0) != 0;
        defer mouse_down_prev = mouse_down;
        mx /= scale;
        my /= scale;
        var win_width: i32 = undefined;
        var win_height: i32 = undefined;
        c.glfwGetWindowSize(window, &win_width, &win_height);
        win_width = @intFromFloat(@as(f32, @floatFromInt(win_width)) / scale);
        win_height = @intFromFloat(@as(f32, @floatFromInt(win_height)) / scale);
        var framebuffer_width: i32 = undefined;
        var framebuffer_height: i32 = undefined;
        c.glfwGetFramebufferSize(window, &framebuffer_width, &framebuffer_height);

        // Calculate pixel ratio for hi-dpi devices.
        const pxRatio = @as(f32, @floatFromInt(framebuffer_width)) / @as(f32, @floatFromInt(win_width));

        const width: f32 = @floatFromInt(win_width);
        const height: f32 = @floatFromInt(win_height);

        const fb_level = if (blur < 1) 0 else std.math.log2(blur);
        const fb_level_int = @min(fb_x.len - 1, @as(usize, @intFromFloat(fb_level)));
        const fb_level_fract = fb_level - @as(f32, @floatFromInt(fb_level_int));
        const blur_biased: f32 = if (fb_level_int == 0) fb_level_fract else 0.5 + 0.5 * fb_level_fract;
        const fb_width: f32 = @floatFromInt(@as(u32, 256) >> @as(u5, @intCast(fb_level_int)));
        c.glViewport(0, 0, @intFromFloat(fb_width), @intFromFloat(fb_width));
        // blur_x
        fb_x[fb_level_int].bind();
        vg.beginFrame(fb_width, fb_width, 1);
        vg.beginPath();
        vg.rect(0, 0, fb_width, fb_width);
        // vg.fillPaint(vg.imagePattern(0, 0, fb_width, fb_width, 0, image_baboon, 1));
        vg.fillPaint(vg.imageBlur(fb_width, fb_width, image_baboon, blur_biased, 0));
        vg.fill();
        vg.endFrame();
        // blur_y
        fb_y[fb_level_int].bind();
        vg.beginFrame(fb_width, fb_width, 1);
        vg.beginPath();
        vg.rect(0, 0, fb_width, fb_width);
        vg.fillPaint(vg.imageBlur(fb_width, fb_width, fb_x[fb_level_int].image, 0, blur_biased));
        vg.fill();
        vg.endFrame();
        Framebuffer.unbind();

        // Update and render
        c.glViewport(0, 0, framebuffer_width, framebuffer_height);
        c.glClearColor(132.0 / 255.0, 152.0 / 255.0, 187.0 / 255.0, 1);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

        vg.beginFrame(@floatFromInt(win_width), @floatFromInt(win_height), pxRatio);

        {
            vg.save();
            defer vg.restore();

            const gap = (width - 2 * 256) / 3;
            var x: f32 = @round(gap);
            const y: f32 = (height - 256) / 2;

            vg.beginPath();
            vg.rect(x, y, 256, 256);
            vg.fillPaint(vg.imagePattern(x, y, 256, 256, 0, image_baboon, 1));
            vg.fill();

            vg.fontFace("sans");
            vg.textAlign(.{ .horizontal = .center });
            vg.fillColor(nvg.rgbf(1, 1, 1));
            vg.fillColor(nvg.rgbaf(0, 0, 0, 0.5));
            _ = vg.text(x + 128, y + 256 + 25, "Original");
            vg.fillColor(nvg.rgbf(1, 1, 1));
            _ = vg.text(x + 128, y + 256 + 24, "Original");

            x = @round(gap + 256 + gap);
            vg.beginPath();
            vg.rect(x, y, 256, 256);
            vg.fillPaint(vg.imagePattern(x, y, 256, 256, 0, fb_y[fb_level_int].image, 1));
            vg.fill();

            var buf: [64]u8 = undefined;
            const blur_text = try std.fmt.bufPrint(&buf, "Blur {d:0.2}px mip_level={d:0.2}", .{ blur, fb_level });
            vg.fillColor(nvg.rgbaf(0, 0, 0, 0.5));
            _ = vg.text(x + 128, y + 256 + 25, blur_text);
            vg.fillColor(nvg.rgbf(1, 1, 1));
            _ = vg.text(x + 128, y + 256 + 24, blur_text);

            // slider control
            const slider_w = 256;
            const slider_x = x;
            const slider_y = y + 256 + 40;
            drawSlider(vg, slider_x, slider_y, slider_w, slider_value);
            if (!mouse_down_prev and mouse_down and pointInRect(mouse_x, mouse_y, slider_x, slider_y - 6, slider_w, 12)) {
                slider_grab = true;
            }
            if (slider_grab) {
                if (mouse_down) {
                    slider_value = std.math.clamp(mouse_x - slider_x, 0, slider_w - 1) / slider_w;
                    blur = std.math.pow(f32, blur_max, slider_value) - 1;
                } else {
                    slider_grab = false;
                }
            }
        }

        fps.draw(vg, 5, 5);

        vg.endFrame();

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
