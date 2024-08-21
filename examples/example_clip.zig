const std = @import("std");
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});

const nvg = @import("nanovg");

var prng = std.Random.DefaultPrng.init(4);
const random = prng.random();

var cursor_shape: Shape = .star;

fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    _ = scancode;
    _ = mods;
    if (key == c.GLFW_KEY_ESCAPE and action == c.GLFW_PRESS)
        c.glfwSetWindowShouldClose(window, c.GL_TRUE);
}

fn mouseButtonCallback(window: ?*c.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.C) void {
    _ = window;
    _ = mods;
    if (button == c.GLFW_MOUSE_BUTTON_LEFT and action == c.GLFW_PRESS) {
        cursor_shape = random.enumValue(Shape);
    }
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

const Shape = enum {
    rect,
    circle,
    donut,
    star,
    heart,
    twitter_logo,

    fn path(shape: Shape, vg: nvg, r: f32) void {
        switch (shape) {
            .rect => vg.rect(-r, -r, 2 * r, 2 * r),
            .circle => vg.circle(0, 0, r),
            .donut => pathDonut(vg, r),
            .star => pathStar(vg, 5, 0.5 * r, r),
            .heart => {
                vg.translate(-r, -r);
                pathHeart(vg, 2 * r, 2 * r);
                vg.translate(r, r);
            },
            .twitter_logo => {
                vg.translate(-r, -r);
                pathTwitterLogo(vg, 2 * r, 2 * r);
                vg.translate(r, r);
            },
        }
    }
};

const cols = 4;
const rows = 4;
const SpinningShape = struct {
    shape: Shape,
    angle: f32,
    angular_vel: f32 = 0,
};
var shapes: [rows][cols]SpinningShape = undefined;

fn spinShapes(w: f32, h: f32, mx: f32, my: f32, dt: f32) void {
    const sx = w / cols;
    const sy = h / rows;
    for (&shapes, 0..) |*shapes_row, row| {
        for (shapes_row, 0..) |*shape, col| {
            const x: f32 = @floatFromInt(col);
            const y: f32 = @floatFromInt(row);
            const dx = sx * (x + 0.5) - mx;
            const dy = sy * (y + 0.5) - my;
            const d = @max(1000, dx * dx + dy * dy);
            shape.angular_vel += std.math.sign(dx) * 10000 / d * dt;
            shape.angle += shape.angular_vel * dt;
            shape.angular_vel -= std.math.sign(shape.angular_vel) * dt;
        }
    }
}

fn pathShapes(vg: nvg, w: f32, h: f32) void {
    const sx = w / cols;
    const sy = h / rows;
    const r = 0.4 * @min(sx, sy);
    for (shapes, 0..) |shapes_row, row| {
        for (shapes_row, 0..) |shape, col| {
            const x: f32 = @floatFromInt(col);
            const y: f32 = @floatFromInt(row);
            vg.save();
            vg.translate(sx * (x + 0.5), sy * (y + 0.5));
            vg.rotate(shape.angle);
            shape.shape.path(vg, r);
            vg.restore();
        }
    }
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
    _ = c.glfwSetMouseButtonCallback(window, mouseButtonCallback);

    c.glfwMakeContextCurrent(window);

    if (c.gladLoadGL() == 0) {
        return error.GLADInitFailed;
    }

    var vg = try nvg.gl.init(allocator, .{
        .debug = true,
    });
    defer vg.deinit();

    c.glfwSwapInterval(0);

    for (&shapes) |*row| {
        for (row) |*cell| {
            cell.* = .{
                .shape = random.enumValue(Shape),
                .angle = random.float(f32) * std.math.tau,
            };
        }
    }

    c.glfwSetTime(0);
    prevt = c.glfwGetTime();

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        const t = c.glfwGetTime();
        const t32: f32 = @floatCast(t);
        const dt = t - prevt;
        prevt = t;

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

        // shape grid
        spinShapes(@floatFromInt(win_width), @floatFromInt(win_height), @floatCast(mx), @floatCast(my), @floatCast(dt));
        vg.beginPath();
        vg.save();
        vg.translate(@floatCast(mx), @floatCast(my));
        cursor_shape.path(vg, 100);
        vg.restore();
        pathShapes(vg, @floatFromInt(win_width), @floatFromInt(win_height));
        vg.strokeColor(nvg.rgbf(1, 1, 1));
        vg.strokeWidth(2);
        vg.stroke();

        // clip cursor with shape grid
        vg.beginPath();
        vg.save();
        vg.translate(@floatCast(mx), @floatCast(my));
        cursor_shape.path(vg, 100);
        vg.restore();
        vg.clip();
        pathShapes(vg, @floatFromInt(win_width), @floatFromInt(win_height));
        vg.fill();

        // draw some random thing in the center
        vg.translate(500, 300);

        vg.beginPath();
        vg.save();
        const s = 1.1 + @cos(4 * t32);
        vg.scale(s, s);
        Shape.heart.path(vg, 100);
        vg.restore();
        vg.strokeColor(nvg.rgb(0, 0, 0));
        vg.strokeWidth(8);
        vg.stroke();
        vg.fillColor(nvg.rgbf(1, 0, 0));
        vg.fill();

        vg.clip();
        vg.rotate(3 * t32);
        Shape.star.path(vg, 100);
        vg.stroke();
        vg.fillColor(nvg.rgbf(1, 1, 0));
        vg.fill();

        vg.endFrame();

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
