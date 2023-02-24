const std = @import("std");

const nvg = @import("nanovg");

pub const PerfGraph = @This();

pub const GraphRenderStyle = enum {
    fps,
    ms,
    percent,
};

style: GraphRenderStyle,
name: []const u8,
values: [100]f32,
head: usize = 0,

pub fn init(style: GraphRenderStyle, name: []const u8) PerfGraph {
    return PerfGraph{
        .style = style,
        .name = name,
        .values = std.mem.zeroes([100]f32),
    };
}

pub fn update(fps: *PerfGraph, frame_time: f32) void {
    fps.head = (fps.head + 1) % fps.values.len;
    fps.values[fps.head] = frame_time;
}

fn getAverage(fps: *PerfGraph) f32 {
    var avg: f32 = 0;
    for (fps.values) |value| {
        avg += value;
    }
    return avg / @intToFloat(f32, fps.values.len);
}

pub fn draw(fps: *PerfGraph, vg: nvg, x: f32, y: f32) void {
    var buf: [64]u8 = undefined;
    const avg = fps.getAverage();

    const w = 200;
    const h = 35;

    vg.beginPath();
    vg.rect(x, y, w, h);
    vg.fillColor(nvg.rgba(0, 0, 0, 128));
    vg.fill();

    vg.beginPath();
    vg.moveTo(x, y + h);
    if (fps.style == .fps) {
        for (fps.values, 0..) |_, i| {
            var v: f32 = 1.0 / (0.00001 + fps.values[(fps.head + i) % fps.values.len]);
            if (v > 80) v = 80;
            const vx = x + (@intToFloat(f32, i) / @intToFloat(f32, fps.values.len - 1)) * w;
            const vy = y + h - ((v / 80) * h);
            vg.lineTo(vx, vy);
        }
    } else if (fps.style == .percent) {
        for (fps.values, 0..) |_, i| {
            var v: f32 = fps.values[(fps.head + i) % fps.values.len];
            if (v > 100) v = 100;
            const vx = x + (@intToFloat(f32, i) / @intToFloat(f32, fps.values.len - 1)) * w;
            const vy = y + h - ((v / 100) * h);
            vg.lineTo(vx, vy);
        }
    } else {
        for (fps.values, 0..) |_, i| {
            var v: f32 = fps.values[(fps.head + i) % fps.values.len] * 1000;
            if (v > 20) v = 20;
            const vx = x + (@intToFloat(f32, i) / @intToFloat(f32, fps.values.len - 1)) * w;
            const vy = y + h - ((v / 20) * h);
            vg.lineTo(vx, vy);
        }
    }
    vg.lineTo(x + w, y + h);
    vg.fillColor(nvg.rgba(255, 192, 0, 128));
    vg.fill();

    vg.fontFace("sans");

    if (fps.name.len > 0) {
        vg.fontSize(12);
        vg.textAlign(.{ .vertical = .top });
        vg.fillColor(nvg.rgba(240, 240, 240, 192));
        _ = vg.text(x + 3, y + 3, fps.name);
    }

    if (fps.style == .fps) {
        vg.fontSize(15);
        vg.textAlign(.{ .horizontal = .right, .vertical = .top });
        vg.fillColor(nvg.rgba(240, 240, 240, 255));
        var str = std.fmt.bufPrint(&buf, "{d:.2} FPS", .{1 / avg}) catch unreachable;
        _ = vg.text(x + w - 3, y + 3, str);
        vg.fontSize(13);
        vg.textAlign(.{ .horizontal = .right, .vertical = .baseline });
        vg.fillColor(nvg.rgba(240, 240, 240, 160));
        str = std.fmt.bufPrint(&buf, "{d:.2} ms", .{avg * 1000}) catch unreachable;
        _ = vg.text(x + w - 3, y + h - 3, str);
    } else if (fps.style == .percent) {
        vg.fontSize(15);
        vg.textAlign(.{ .horizontal = .right, .vertical = .top });
        vg.fillColor(nvg.rgba(240, 240, 240, 255));
        const str = std.fmt.bufPrint(&buf, "{d:.1} %", .{avg}) catch unreachable;
        _ = vg.text(x + w - 3, y + 3, str);
    } else {
        vg.fontSize(15);
        vg.textAlign(.{ .horizontal = .right, .vertical = .top });
        vg.fillColor(nvg.rgba(240, 240, 240, 255));
        const str = std.fmt.bufPrint(&buf, "{d:.2} ms", .{avg * 1000}) catch unreachable;
        _ = vg.text(x + w - 3, y + 3, str);
    }
}
