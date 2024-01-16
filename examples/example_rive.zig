const std = @import("std");
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
    @cInclude("rive_capi.h");
});

var allocator: std.mem.Allocator = undefined;

fn getNanoVGContext(ctx: ?*anyopaque) *nvg {
    return @ptrCast(@alignCast(ctx));
}

const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

const ClipPath = struct {
    rect: ?Rect,
    points: []const f32,
    verbs: []const u8,
    transform: [6]f32,

    fn initDefault() ClipPath {
        return .{
            .rect = null,
            .points = &.{},
            .verbs = &.{},
            .transform = [6]f32{ 1, 0, 0, 1, 0, 0 },
        };
    }
};
var clip_path_stack: std.ArrayList(ClipPath) = undefined;

fn riveSave(ctx: ?*anyopaque) callconv(.C) void {
    const vg: *nvg = getNanoVGContext(ctx);
    vg.save();
    clip_path_stack.append(clip_path_stack.getLast()) catch unreachable;
}

fn riveRestore(ctx: ?*anyopaque) callconv(.C) void {
    const vg: *nvg = getNanoVGContext(ctx);
    vg.restore();
    _ = clip_path_stack.pop();
}

fn riveTransform(ctx: ?*anyopaque, mat2d_ptr: [*c]const f32) callconv(.C) void {
    const vg: *nvg = getNanoVGContext(ctx);
    vg.transform(mat2d_ptr[0], mat2d_ptr[1], mat2d_ptr[2], mat2d_ptr[3], mat2d_ptr[4], mat2d_ptr[5]);
}

fn rivePath(vg: *nvg, points: []const f32, verbs: []const u8) void {
    var i: usize = 0;
    for (verbs) |verb| {
        switch (verb) {
            c.RIVE_PATH_VERB_MOVE => {
                vg.moveTo(points[i], points[i + 1]);
                i += 2;
            },
            c.RIVE_PATH_VERB_LINE => {
                vg.lineTo(points[i], points[i + 1]);
                i += 2;
            },
            c.RIVE_PATH_VERB_QUAD => {
                vg.quadTo(points[i], points[i + 1], points[i + 2], points[i + 3]);
                i += 4;
            },
            c.RIVE_PATH_VERB_CUBIC => {
                vg.bezierTo(points[i], points[i + 1], points[i + 2], points[i + 3], points[i + 4], points[i + 5]);
                i += 6;
            },
            c.RIVE_PATH_VERB_CLOSE => {
                vg.closePath();
            },
            else => {
                @panic("unknown verb");
            },
        }
    }
}

fn convertPathToRect(points: []const f32, verbs: []const u8) ?Rect {
    if (points.len != 8 or verbs.len != 5) return null;
    if (verbs[0] != c.RIVE_PATH_VERB_MOVE or
        verbs[1] != c.RIVE_PATH_VERB_LINE or
        verbs[2] != c.RIVE_PATH_VERB_LINE or
        verbs[3] != c.RIVE_PATH_VERB_LINE or
        verbs[4] != c.RIVE_PATH_VERB_CLOSE) return null;
    const eps = 0.001;
    if (!std.math.approxEqAbs(f32, points[1], points[3], eps) or
        !std.math.approxEqAbs(f32, points[2], points[4], eps) or
        !std.math.approxEqAbs(f32, points[5], points[7], eps) or
        !std.math.approxEqAbs(f32, points[6], points[0], eps)) return null;
    return .{
        .x = points[0],
        .y = points[1],
        .w = points[4] - points[0],
        .h = points[5] - points[1],
    };
}

fn riveClipPath(
    ctx: ?*anyopaque,
    points_ptr: [*c]const f32,
    points_len: usize,
    verbs_ptr: [*c]const u8,
    verbs_len: usize,
) callconv(.C) void {
    if (verbs_len == 0) return;

    const vg: *nvg = getNanoVGContext(ctx);
    const points = points_ptr[0..points_len];
    const verbs = verbs_ptr[0..verbs_len];

    const clip_path = &clip_path_stack.items[clip_path_stack.items.len - 1];
    clip_path.* = ClipPath.initDefault();
    if (convertPathToRect(points, verbs)) |rect| {
        // std.debug.print("rect {}\n", .{rect});
        clip_path.rect = rect;
    } else {
        clip_path.points = points;
        clip_path.verbs = verbs;
    }
    vg.currentTransform(&clip_path.transform);
}

fn riveDrawPath(
    ctx: ?*anyopaque,
    points_ptr: [*c]const f32,
    points_len: usize,
    verbs_ptr: [*c]const u8,
    verbs_len: usize,
    paint_ptr: [*c]const c.RivePaint,
) callconv(.C) void {
    if (verbs_len == 0) return;

    const vg: *nvg = getNanoVGContext(ctx);
    const points = points_ptr[0..points_len];
    const verbs = verbs_ptr[0..verbs_len];
    const paint = paint_ptr.*;

    vg.beginPath();
    const clip_path = clip_path_stack.getLast();
    if (clip_path.points.len > 0) {
        var ct: [6]f32 = undefined;
        vg.currentTransform(&ct);
        defer {
            vg.resetTransform();
            vg.transform(ct[0], ct[1], ct[2], ct[3], ct[4], ct[5]);
        }
        vg.resetTransform();
        const t = &clip_path.transform;
        vg.transform(t[0], t[1], t[2], t[3], t[4], t[5]);
        rivePath(vg, clip_path.points, clip_path.verbs);
        vg.clip();
    }

    rivePath(vg, points, verbs);
    const comp = std.mem.asBytes(&paint.color);
    const comp1 = std.mem.asBytes(&paint.color1);
    const color = nvg.rgba(comp[2], comp[1], comp[0], comp[3]);
    const color1 = nvg.rgba(comp1[2], comp1[1], comp1[0], comp1[3]);
    if (paint.style == 0) vg.strokeWidth(paint.thickness);
    if (paint.gradient == 0) {
        if (paint.style == 0) {
            vg.strokeColor(color);
            vg.stroke();
        } else {
            vg.fillColor(color);
            vg.fill();
        }
    } else {
        const gradient = if (paint.gradient == 1)
            vg.linearGradient(paint.sx, paint.sy, paint.ex, paint.ey, color, color1)
        else
            vg.radialGradient(paint.sx, paint.sy, 0, paint.ex, color, color1);
        if (paint.style == 0) {
            vg.strokePaint(gradient);
            vg.stroke();
        } else {
            vg.fillPaint(gradient);
            vg.fill();
        }
    }
}

const PerfGraph = @import("perf.zig");

const nvg = @import("nanovg");

var blowup: bool = false;
var premult: bool = false;

fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    _ = scancode;
    _ = mods;
    if (key == c.GLFW_KEY_ESCAPE and action == c.GLFW_PRESS)
        c.glfwSetWindowShouldClose(window, c.GL_TRUE);
    if (key == c.GLFW_KEY_SPACE and action == c.GLFW_PRESS)
        blowup = !blowup;
    if (key == c.GLFW_KEY_P and action == c.GLFW_PRESS)
        premult = !premult;
}

pub fn main() !void {
    var window: ?*c.GLFWwindow = null;
    var prevt: f64 = 0;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

    clip_path_stack = std.ArrayList(ClipPath).init(allocator);
    try clip_path_stack.append(ClipPath.initDefault());

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
    window = c.glfwCreateWindow(@intFromFloat(scale * 1000), @intFromFloat(scale * 600), "NanoVG + Rive", null, null);
    if (window == null) {
        return error.GLFWInitFailed;
    }
    defer c.glfwDestroyWindow(window);

    _ = c.glfwSetKeyCallback(window, keyCallback);

    c.glfwMakeContextCurrent(window);
    c.glfwSwapInterval(0);

    if (c.gladLoadGL() == 0) {
        return error.GLADInitFailed;
    }

    var vg = try nvg.gl.init(allocator, .{
        .debug = true,
    });
    defer vg.deinit();

    _ = vg.createFontMem("sans", @embedFile("Roboto-Regular.ttf"));
    var fps = PerfGraph.init(.fps, "Frame Time");

    const data = try std.fs.cwd().readFileAlloc(allocator, "examples/animated-emojis.riv", 1 << 24);
    defer allocator.free(data);

    const rive_renderer = c.riveRendererCreate(@ptrCast(&vg), c.RiveRendererInterface{
        .save = riveSave,
        .restore = riveRestore,
        .transform = riveTransform,
        .clipPath = riveClipPath,
        .drawPath = riveDrawPath,
    });

    const rive_file = c.riveFileImport(data.ptr, data.len);
    defer c.riveFileDestroy(rive_file);

    std.log.info("artboardCount={}", .{c.riveFileArtboardCount(rive_file)});
    const artboard = c.riveFileArtboardAt(rive_file, 0);
    c.riveArtboardAdvance(artboard, 0);
    var bounds: [4]f32 = undefined;
    c.riveArtboardBounds(artboard, &bounds);
    std.log.info("artboardBounds={any}", .{bounds});
    const scene = c.riveArtboardAnimationAt(artboard, 0);

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

        {
            vg.scale(0.5, 0.5);
            defer vg.resetTransform();
            c.riveSceneAdvanceAndApply(scene, @floatCast(dt));
            c.riveArtboardDraw(artboard, rive_renderer);
        }
        fps.draw(vg, 5, 5);

        vg.endFrame();

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
