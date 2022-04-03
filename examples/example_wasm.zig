const std = @import("std");

const nvg = @import("nanovg");

const wasm = @import("web/wasm.zig");
const gl = @import("web/webgl.zig");
const keys = @import("web/keys.zig");
const console = @import("web/console.zig");

const Demo = @import("demo.zig");

var video_width: f32 = 1280;
var video_height: f32 = 720;
var video_scale: f32 = 1;

var gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
var allocator: std.mem.Allocator = undefined;
var vg: nvg = undefined;
var demo: Demo = undefined;

var mx: f32 = 0;
var my: f32 = 0;
var blowup: bool = false;

export fn onInit() void {
    gpa =  std.heap.GeneralPurposeAllocator(.{}){};
    allocator = gpa.allocator();
    wasm.global_allocator = allocator;

    vg = nvg.gl.init(allocator, .{}) catch {
        console.log("Failed to create NanoVG", .{});
        return;
    };

    demo.load(vg);
}

export fn onResize(w: c_uint, h: c_uint, s: f32) void {
    video_width = @intToFloat(f32, w);
    video_height = @intToFloat(f32, h);
    video_scale = s;
    gl.glViewport(0, 0, @floatToInt(i32, s * video_width), @floatToInt(i32, s * video_height));
}

export fn onKeyDown(key: c_uint) void {
    if (key == keys.KEY_SPACE) blowup = !blowup;
}

export fn onMouseMove(x: i32, y: i32) void {
    mx = @intToFloat(f32, x);
    my = @intToFloat(f32, y);
}

var frame: usize = 0;
export fn onAnimationFrame() void {
    gl.glClearColor(0.3, 0.3, 0.32, 1.0);
    gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

    vg.beginFrame(video_width, video_height, video_scale);

    const t = wasm.performanceNow() / 1000.0;
    demo.draw(vg, mx, my, video_width, video_height, t, blowup);

    vg.endFrame();
}
