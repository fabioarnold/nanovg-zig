const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const c = @cImport({
    @cDefine("STBI_WRITE_NO_STDIO", "1");
    @cInclude("stb_image_write.h");
});
const use_webgl = builtin.cpu.arch.isWasm();
const gl = if (use_webgl)
    @import("web/webgl.zig")
else
    @cImport({
        @cInclude("glad/glad.h");
    });

const nvg = @import("nanovg");

const Demo = @This();

fontNormal: nvg.Font,
fontBold: nvg.Font,
fontIcons: nvg.Font,
fontEmoji: nvg.Font,
images: [12]nvg.Image,

const ICON_SEARCH = 0x1F50D;
const ICON_CIRCLED_CROSS = 0x2716;
const ICON_CHEVRON_RIGHT = 0xE75E;
const ICON_CHECK = 0x2713;
const ICON_LOGIN = 0xE740;
const ICON_TRASH = 0xE729;

fn cpToUTF8(cp: u21, buf: []u8) [:0]const u8 {
    const len = std.unicode.utf8Encode(cp, buf) catch unreachable;
    buf[len] = 0;
    return @ptrCast(buf[0..len]);
}

fn isBlack(col: nvg.Color) bool {
    return col.r == 0 and col.g == 0 and col.b == 0 and col.a == 0;
}

const image_files = [_][]const u8{
    @embedFile("images/image1.jpg"),
    @embedFile("images/image2.jpg"),
    @embedFile("images/image3.jpg"),
    @embedFile("images/image4.jpg"),
    @embedFile("images/image5.jpg"),
    @embedFile("images/image6.jpg"),
    @embedFile("images/image7.jpg"),
    @embedFile("images/image8.jpg"),
    @embedFile("images/image9.jpg"),
    @embedFile("images/image10.jpg"),
    @embedFile("images/image11.jpg"),
    @embedFile("images/image12.jpg"),
};

pub fn load(demo: *Demo, vg: nvg) void {
    for (&demo.images, 0..) |*image, i| {
        image.* = vg.createImageMem(image_files[i], .{});
    }

    const entypo = @embedFile("entypo.ttf");
    demo.fontIcons = vg.createFontMem("icons", entypo);
    const normal = @embedFile("Roboto-Regular.ttf");
    demo.fontNormal = vg.createFontMem("sans", normal);
    const bold = @embedFile("Roboto-Bold.ttf");
    demo.fontBold = vg.createFontMem("sans-bold", bold);
    const emoji = @embedFile("NotoEmoji-Regular.ttf");
    demo.fontEmoji = vg.createFontMem("emoji", emoji);
    _ = vg.addFallbackFontId(demo.fontNormal, demo.fontEmoji);
    _ = vg.addFallbackFontId(demo.fontBold, demo.fontEmoji);
}

pub fn free(demo: Demo, vg: nvg) void {
    for (demo.images) |image| {
        vg.deleteImage(image);
    }
}

pub fn draw(demo: Demo, vg: nvg, mx: f32, my: f32, width: f32, height: f32, t: f32, blowup: bool) void {
    drawEyes(vg, width - 250, 50, 150, 100, mx, my, t);
    drawParagraph(vg, width - 450, 50, 150, 100, mx, my);
    drawGraph(vg, 0, height / 2, width, height / 2, t);
    drawColorwheel(vg, width - 300, height - 300, 250, 250, t);

    // Line joints
    drawLines(vg, 120, height - 50, 600, 50, t);

    // Line widths
    drawWidths(vg, 10, 50, 30);

    // Line caps
    drawCaps(vg, 10, 300, 30);

    drawScissor(vg, 50, height - 80, t);

    vg.save();
    if (blowup) {
        vg.rotate(@sin(t * 0.3) * 5.0 / 180.0 * std.math.pi);
        vg.scale(2.0, 2.0);
    }

    // Widgets
    drawWindow(vg, "Widgets `n Stuff", 50, 50, 300, 400);
    const x: f32 = 60;
    var y: f32 = 95;
    drawSearchBox(vg, "Search", x, y, 280, 25);
    y += 40;
    drawDropDown(vg, "Effects", x, y, 280, 28);
    const popy = y + 14;
    y += 45;

    // Form
    drawLabel(vg, "Login", x, y, 280, 20);
    y += 25;
    drawEditBox(vg, "Email", x, y, 280, 28);
    y += 35;
    drawEditBox(vg, "Password", x, y, 280, 28);
    y += 38;
    drawCheckBox(vg, "Remember me", x, y, 140, 28);
    drawButton(vg, ICON_LOGIN, "Sign in", x + 138, y, 140, 28, nvg.rgba(0, 96, 128, 255));
    y += 45;

    // Slider
    drawLabel(vg, "Diameter", x, y, 280, 20);
    y += 25;
    drawEditBoxNum(vg, "123.00", "px", x + 180, y, 100, 28);
    drawSlider(vg, 0.4, x, y, 170, 28);
    y += 55;

    drawButton(vg, ICON_TRASH, "Delete", x, y, 160, 28, nvg.rgba(128, 16, 8, 255));
    drawButton(vg, 0, "Cancel", x + 170, y, 110, 28, nvg.rgba(0, 0, 0, 0));

    // Thumbnails box
    drawThumbnails(vg, 365, popy - 30, 160, 300, demo.images[0..], t);

    vg.restore();
}

fn drawWindow(vg: nvg, title: [:0]const u8, x: f32, y: f32, w: f32, h: f32) void {
    const cornerRadius = 3;
    var shadowPaint: nvg.Paint = undefined;
    var headerPaint: nvg.Paint = undefined;

    vg.save();

    // Window
    vg.beginPath();
    vg.roundedRect(x, y, w, h, cornerRadius);
    vg.fillColor(nvg.rgba(28, 30, 34, 192));
    vg.fill();

    // Drop shadow
    shadowPaint = vg.boxGradient(x, y + 2, w, h, cornerRadius * 2, 10, nvg.rgba(0, 0, 0, 128), nvg.rgba(0, 0, 0, 0));
    vg.beginPath();
    vg.rect(x - 10, y - 10, w + 20, h + 30);
    vg.roundedRect(x, y, w, h, cornerRadius);
    vg.pathWinding(nvg.Winding.solidity(.hole));
    vg.fillPaint(shadowPaint);
    vg.fill();

    // Header
    headerPaint = vg.linearGradient(x, y, x, y + 15, nvg.rgba(255, 255, 255, 8), nvg.rgba(0, 0, 0, 16));
    vg.beginPath();
    vg.roundedRect(x + 1, y + 1, w - 2, 30, cornerRadius - 1);
    vg.fillPaint(headerPaint);
    vg.fill();
    vg.beginPath();
    vg.moveTo(x + 0.5, y + 0.5 + 30);
    vg.lineTo(x + 0.5 + w - 1, y + 0.5 + 30);
    vg.strokeColor(nvg.rgba(0, 0, 0, 32));
    vg.stroke();

    vg.fontSize(15.0);
    vg.fontFace("sans-bold");
    vg.textAlign(.{ .horizontal = .center, .vertical = .middle });

    vg.fontBlur(2);
    vg.fillColor(nvg.rgba(0, 0, 0, 128));
    _ = vg.text(x + w / 2, y + 16 + 1, title);

    vg.fontBlur(0);
    vg.fillColor(nvg.rgba(220, 220, 220, 160));
    _ = vg.text(x + w / 2, y + 16, title);

    vg.restore();
}

fn drawSearchBox(vg: nvg, text: [:0]const u8, x: f32, y: f32, w: f32, h: f32) void {
    var icon: [8]u8 = undefined;
    const cornerRadius = h / 2 - 1;

    // Edit
    const bg = vg.boxGradient(x, y + 1.5, w, h, h / 2, 5, nvg.rgba(0, 0, 0, 16), nvg.rgba(0, 0, 0, 92));
    vg.beginPath();
    vg.roundedRect(x, y, w, h, cornerRadius);
    vg.fillPaint(bg);
    vg.fill();

    vg.fontSize(h * 1.3);
    vg.fontFace("icons");
    vg.fillColor(nvg.rgba(255, 255, 255, 64));
    vg.textAlign(.{ .horizontal = .center, .vertical = .middle });
    _ = vg.text(x + h * 0.55, y + h * 0.55, cpToUTF8(ICON_SEARCH, &icon));

    vg.fontSize(17.0);
    vg.fontFace("sans");
    vg.fillColor(nvg.rgba(255, 255, 255, 32));

    vg.textAlign(.{ .horizontal = .left, .vertical = .middle });
    _ = vg.text(x + h * 1.05, y + h * 0.5, text);

    vg.fontSize(h * 1.3);
    vg.fontFace("icons");
    vg.fillColor(nvg.rgba(255, 255, 255, 32));
    vg.textAlign(.{ .horizontal = .center, .vertical = .middle });
    _ = vg.text(x + w - h * 0.55, y + h * 0.55, cpToUTF8(ICON_CIRCLED_CROSS, &icon));
}

fn drawDropDown(vg: nvg, text: [:0]const u8, x: f32, y: f32, w: f32, h: f32) void {
    var icon: [8]u8 = undefined;
    const cornerRadius = 4.0;

    const bg = vg.linearGradient(x, y, x, y + h, nvg.rgba(255, 255, 255, 16), nvg.rgba(0, 0, 0, 16));
    vg.beginPath();
    vg.roundedRect(x + 1, y + 1, w - 2, h - 2, cornerRadius - 1.0);
    vg.fillPaint(bg);
    vg.fill();

    vg.beginPath();
    vg.roundedRect(x + 0.5, y + 0.5, w - 1, h - 1, cornerRadius - 0.5);
    vg.strokeColor(nvg.rgba(0, 0, 0, 48));
    vg.stroke();

    vg.fontSize(17.0);
    vg.fontFace("sans");
    vg.fillColor(nvg.rgba(255, 255, 255, 160));
    vg.textAlign(.{ .horizontal = .left, .vertical = .middle });
    _ = vg.text(x + h * 0.3, y + h * 0.5, text);

    vg.fontSize(h * 1.3);
    vg.fontFace("icons");
    vg.fillColor(nvg.rgba(255, 255, 255, 64));
    vg.textAlign(.{ .horizontal = .center, .vertical = .middle });
    _ = vg.text(x + w - h * 0.5, y + h * 0.5, cpToUTF8(ICON_CHEVRON_RIGHT, &icon));
}

fn drawLabel(vg: nvg, text: [:0]const u8, x: f32, y: f32, w: f32, h: f32) void {
    _ = w;

    vg.fontSize(15.0);
    vg.fontFace("sans");
    vg.fillColor(nvg.rgba(255, 255, 255, 128));

    vg.textAlign(.{ .horizontal = .left, .vertical = .middle });
    _ = vg.text(x, y + h * 0.5, text);
}

fn drawEditBoxBase(vg: nvg, x: f32, y: f32, w: f32, h: f32) void {
    // Edit
    const bg = vg.boxGradient(x + 1, y + 1 + 1.5, w - 2, h - 2, 3, 4, nvg.rgba(255, 255, 255, 32), nvg.rgba(32, 32, 32, 32));
    vg.beginPath();
    vg.roundedRect(x + 1, y + 1, w - 2, h - 2, 4 - 1);
    vg.fillPaint(bg);
    vg.fill();

    vg.beginPath();
    vg.roundedRect(x + 0.5, y + 0.5, w - 1, h - 1, 4 - 0.5);
    vg.strokeColor(nvg.rgba(0, 0, 0, 48));
    vg.stroke();
}

fn drawEditBox(vg: nvg, text: [:0]const u8, x: f32, y: f32, w: f32, h: f32) void {
    drawEditBoxBase(vg, x, y, w, h);

    vg.fontSize(17.0);
    vg.fontFace("sans");
    vg.fillColor(nvg.rgba(255, 255, 255, 64));
    vg.textAlign(.{ .horizontal = .left, .vertical = .middle });
    _ = vg.text(x + h * 0.3, y + h * 0.5, text);
}

fn drawEditBoxNum(vg: nvg, text: [:0]const u8, units: [:0]const u8, x: f32, y: f32, w: f32, h: f32) void {
    drawEditBoxBase(vg, x, y, w, h);

    const uw = vg.textBounds(0, 0, units, null);

    vg.fontSize(15.0);
    vg.fontFace("sans");
    vg.fillColor(nvg.rgba(255, 255, 255, 64));
    vg.textAlign(.{ .horizontal = .right, .vertical = .middle });
    _ = vg.text(x + w - h * 0.3, y + h * 0.5, units);

    vg.fontSize(17.0);
    vg.fontFace("sans");
    vg.fillColor(nvg.rgba(255, 255, 255, 128));
    vg.textAlign(.{ .horizontal = .right, .vertical = .middle });
    _ = vg.text(x + w - uw - h * 0.5, y + h * 0.5, text);
}

fn drawCheckBox(vg: nvg, text: [:0]const u8, x: f32, y: f32, w: f32, h: f32) void {
    var icon: [8]u8 = undefined;
    _ = w;

    vg.fontSize(15.0);
    vg.fontFace("sans");
    vg.fillColor(nvg.rgba(255, 255, 255, 160));

    vg.textAlign(.{ .horizontal = .left, .vertical = .middle });
    _ = vg.text(x + 28, y + h * 0.5, text);

    const bg = vg.boxGradient(x + 1, y + @round(h * 0.5) - 9 + 1, 18, 18, 3, 3, nvg.rgba(0, 0, 0, 32), nvg.rgba(0, 0, 0, 92));
    vg.beginPath();
    vg.roundedRect(x + 1, y + @round(h * 0.5) - 9, 18, 18, 3);
    vg.fillPaint(bg);
    vg.fill();

    vg.fontSize(33);
    vg.fontFace("icons");
    vg.fillColor(nvg.rgba(255, 255, 255, 128));
    vg.textAlign(.{ .horizontal = .center, .vertical = .middle });
    _ = vg.text(x + 9 + 2, y + h * 0.5, cpToUTF8(ICON_CHECK, &icon));
}

fn drawButton(vg: nvg, preicon: u21, text: [:0]const u8, x: f32, y: f32, w: f32, h: f32, col: nvg.Color) void {
    var icon: [8]u8 = undefined;
    const cornerRadius = 4.0;
    var iw: f32 = 0;

    const alpha: u8 = if (isBlack(col)) 16 else 32;
    const bg = vg.linearGradient(x, y, x, y + h, nvg.rgba(255, 255, 255, alpha), nvg.rgba(0, 0, 0, alpha));
    vg.beginPath();
    vg.roundedRect(x + 1, y + 1, w - 2, h - 2, cornerRadius - 1.0);
    if (!isBlack(col)) {
        vg.fillColor(col);
        vg.fill();
    }
    vg.fillPaint(bg);
    vg.fill();

    vg.beginPath();
    vg.roundedRect(x + 0.5, y + 0.5, w - 1, h - 1, cornerRadius - 0.5);
    vg.strokeColor(nvg.rgba(0, 0, 0, 48));
    vg.stroke();

    vg.fontSize(17.0);
    vg.fontFace("sans-bold");
    const tw = vg.textBounds(0, 0, text, null);
    if (preicon != 0) {
        vg.fontSize(h * 1.3);
        vg.fontFace("icons");
        iw = vg.textBounds(0, 0, cpToUTF8(preicon, &icon), null);
        iw += h * 0.15;
    }

    if (preicon != 0) {
        vg.fontSize(h * 1.3);
        vg.fontFace("icons");
        vg.fillColor(nvg.rgba(255, 255, 255, 96));
        vg.textAlign(.{ .horizontal = .left, .vertical = .middle });
        _ = vg.text(x + w * 0.5 - tw * 0.5 - iw * 0.75, y + h * 0.5, cpToUTF8(preicon, &icon));
    }

    vg.fontSize(17.0);
    vg.fontFace("sans-bold");
    vg.textAlign(.{ .horizontal = .left, .vertical = .middle });
    vg.fillColor(nvg.rgba(0, 0, 0, 160));
    _ = vg.text(x + w * 0.5 - tw * 0.5 + iw * 0.25, y + h * 0.5 - 1, text);
    vg.fillColor(nvg.rgba(255, 255, 255, 160));
    _ = vg.text(x + w * 0.5 - tw * 0.5 + iw * 0.25, y + h * 0.5, text);
}

fn drawSlider(vg: nvg, pos: f32, x: f32, y: f32, w: f32, h: f32) void {
    const cy = y + @round(h * 0.5);
    const kr = @round(h * 0.25);

    vg.save();
    vg.restore();

    // Slot
    var bg = vg.boxGradient(x, cy - 2 + 1, w, 4, 2, 2, nvg.rgba(0, 0, 0, 32), nvg.rgba(0, 0, 0, 128));
    vg.beginPath();
    vg.roundedRect(x, cy - 2, w, 4, 2);
    vg.fillPaint(bg);
    vg.fill();

    // Knob Shadow
    bg = vg.radialGradient(x + @round(pos * w), cy + 1, kr - 3, kr + 3, nvg.rgba(0, 0, 0, 64), nvg.rgba(0, 0, 0, 0));
    vg.beginPath();
    vg.rect(x + @round(pos * w) - kr - 5, cy - kr - 5, kr * 2 + 5 + 5, kr * 2 + 5 + 5 + 3);
    vg.circle(x + @round(pos * w), cy, kr);
    vg.pathWinding(nvg.Winding.solidity(.hole));
    vg.fillPaint(bg);
    vg.fill();

    // Knob
    const knob = vg.linearGradient(x, cy - kr, x, cy + kr, nvg.rgba(255, 255, 255, 16), nvg.rgba(0, 0, 0, 16));
    vg.beginPath();
    vg.circle(x + @round(pos * w), cy, kr - 1);
    vg.fillColor(nvg.rgba(40, 43, 48, 255));
    vg.fill();
    vg.fillPaint(knob);
    vg.fill();

    vg.beginPath();
    vg.circle(x + @round(pos * w), cy, kr - 0.5);
    vg.strokeColor(nvg.rgba(0, 0, 0, 92));
    vg.stroke();
}

fn drawEyes(vg: nvg, x: f32, y: f32, w: f32, h: f32, mx: f32, my: f32, t: f32) void {
    const ex = w * 0.23;
    const ey = h * 0.5;
    const lx = x + ex;
    const ly = y + ey;
    const rx = x + w - ex;
    const ry = y + ey;
    const br = (if (ex < ey) ex else ey) * 0.5;
    const blink = 1 - std.math.pow(f32, @sin(t * 0.5), 200) * 0.8;

    var bg = vg.linearGradient(x, y + h * 0.5, x + w * 0.1, y + h, nvg.rgba(0, 0, 0, 32), nvg.rgba(0, 0, 0, 16));
    vg.beginPath();
    vg.ellipse(lx + 3.0, ly + 16.0, ex, ey);
    vg.ellipse(rx + 3.0, ry + 16.0, ex, ey);
    vg.fillPaint(bg);
    vg.fill();

    bg = vg.linearGradient(x, y + h * 0.25, x + w * 0.1, y + h, nvg.rgba(220, 220, 220, 255), nvg.rgba(128, 128, 128, 255));
    vg.beginPath();
    vg.ellipse(lx, ly, ex, ey);
    vg.ellipse(rx, ry, ex, ey);
    vg.fillPaint(bg);
    vg.fill();

    var dx = (mx - rx) / (ex * 10);
    var dy = (my - ry) / (ey * 10);
    var d = @sqrt(dx * dx + dy * dy);
    if (d > 1.0) {
        dx /= d;
        dy /= d;
    }
    dx *= ex * 0.4;
    dy *= ey * 0.5;
    vg.beginPath();
    vg.ellipse(lx + dx, ly + dy + ey * 0.25 * (1 - blink), br, br * blink);
    vg.fillColor(nvg.rgba(32, 32, 32, 255));
    vg.fill();

    dx = (mx - rx) / (ex * 10);
    dy = (my - ry) / (ey * 10);
    d = @sqrt(dx * dx + dy * dy);
    if (d > 1.0) {
        dx /= d;
        dy /= d;
    }
    dx *= ex * 0.4;
    dy *= ey * 0.5;
    vg.beginPath();
    vg.ellipse(rx + dx, ry + dy + ey * 0.25 * (1 - blink), br, br * blink);
    vg.fillColor(nvg.rgba(32, 32, 32, 255));
    vg.fill();

    var gloss = vg.radialGradient(lx - ex * 0.25, ly - ey * 0.5, ex * 0.1, ex * 0.75, nvg.rgba(255, 255, 255, 128), nvg.rgba(255, 255, 255, 0));
    vg.beginPath();
    vg.ellipse(lx, ly, ex, ey);
    vg.fillPaint(gloss);
    vg.fill();

    gloss = vg.radialGradient(rx - ex * 0.25, ry - ey * 0.5, ex * 0.1, ex * 0.75, nvg.rgba(255, 255, 255, 128), nvg.rgba(255, 255, 255, 0));
    vg.beginPath();
    vg.ellipse(rx, ry, ex, ey);
    vg.fillPaint(gloss);
    vg.fill();
}

fn drawParagraph(vg: nvg, x_arg: f32, y_arg: f32, width: f32, height: f32, mx: f32, my: f32) void {
    const x = x_arg;
    var y = y_arg;
    _ = height;
    var rows: [3]nvg.TextRow = undefined;
    var glyphs: [100]nvg.GlyphPosition = undefined;
    const text = "This is longer chunk of text.\n  \n  Would have used lorem ipsum but she    was busy jumping over the lazy dog with the fox and all the men who came to the aid of the party.🎉";
    var start: []const u8 = undefined;
    var lnum: i32 = 0;
    var px: f32 = undefined;
    var bounds: [4]f32 = undefined;
    const hoverText = "Hover your mouse over the text to see calculated caret position.";
    var gx: f32 = undefined;
    var gy: f32 = undefined;
    var gutter: i32 = 0;

    vg.save();

    vg.fontSize(15.0);
    vg.fontFace("sans");
    vg.textAlign(.{ .vertical = .top });
    var lineh: f32 = undefined;
    vg.textMetrics(null, null, &lineh);

    // The text break API can be used to fill a large buffer of rows,
    // or to iterate over the text just few lines (or just one) at a time.
    // The "next" variable of the last returned item tells where to continue.
    start = text;
    var nrows = vg.textBreakLines(start, width, &rows);
    while (nrows != 0) : (nrows = vg.textBreakLines(start, width, &rows)) {
        var i: u32 = 0;
        while (i < nrows) : (i += 1) {
            const row = &rows[i];
            const hit = mx > x and mx < (x + width) and my >= y and my < (y + lineh);

            vg.beginPath();
            vg.fillColor(nvg.rgba(255, 255, 255, if (hit) 64 else 16));
            vg.rect(x + row.minx, y, row.maxx - row.minx, lineh);
            vg.fill();

            vg.fillColor(nvg.rgba(255, 255, 255, 255));
            _ = vg.text(x, y, row.text);

            if (hit) {
                var caretx = if (mx < x + row.width / 2) x else x + row.width;
                px = x;
                const nglyphs = vg.textGlyphPositions(x, y, row.text, &glyphs);
                for (glyphs[0..nglyphs], 0..) |glyph, j| {
                    const x0 = glyph.x;
                    const x1 = if (j + 1 < nglyphs) glyphs[j + 1].x else x + row.width;
                    gx = x0 * 0.3 + x1 * 0.7;
                    if (mx >= px and mx < gx)
                        caretx = glyph.x;
                    px = gx;
                }
                vg.beginPath();
                vg.fillColor(nvg.rgba(255, 192, 0, 255));
                vg.rect(caretx, y, 1, lineh);
                vg.fill();

                gutter = lnum + 1;
                gx = x - 10;
                gy = y + lineh / 2;
            }
            lnum += 1;
            y += lineh;
        }
        // Keep going...
        start = rows[nrows - 1].next;
    }

    if (gutter != 0) {
        var buf: [16]u8 = undefined;
        const txt = std.fmt.bufPrint(&buf, "{}", .{gutter}) catch unreachable;
        vg.fontSize(12.0);
        vg.textAlign(.{ .horizontal = .right, .vertical = .middle });

        _ = vg.textBounds(gx, gy, txt, &bounds);

        vg.beginPath();
        vg.fillColor(nvg.rgba(255, 192, 0, 255));
        vg.roundedRect(@round(bounds[0] - 4), @round(bounds[1] - 2), @round(bounds[2] - bounds[0]) + 8, @round(bounds[3] - bounds[1]) + 4, (@round(bounds[3] - bounds[1]) + 4) / 2 - 1);
        vg.fill();

        vg.fillColor(nvg.rgba(32, 32, 32, 255));
        _ = vg.text(gx, gy, txt);
    }

    y += 20.0;

    vg.fontSize(11.0);
    vg.textAlign(.{ .vertical = .top });
    vg.textLineHeight(1.2);

    _ = vg.textBoxBounds(x, y, 150, hoverText, &bounds);

    // Fade the tooltip out when close to it.
    gx = std.math.clamp(mx, bounds[0], bounds[2]) - mx;
    gy = std.math.clamp(my, bounds[1], bounds[3]) - my;
    const a = std.math.clamp(@sqrt(gx * gx + gy * gy) / 30.0, 0, 1);
    vg.globalAlpha(a);

    vg.beginPath();
    vg.fillColor(nvg.rgba(220, 220, 220, 255));
    vg.roundedRect(bounds[0] - 2, bounds[1] - 2, @round(bounds[2] - bounds[0]) + 4, @round(bounds[3] - bounds[1]) + 4, 3);
    px = @round((bounds[2] + bounds[0]) / 2);
    vg.moveTo(px, bounds[1] - 10);
    vg.lineTo(px + 7, bounds[1] + 1);
    vg.lineTo(px - 7, bounds[1] + 1);
    vg.fill();

    vg.fillColor(nvg.rgba(0, 0, 0, 220));
    vg.textBox(x, y, 150, hoverText);

    vg.restore();
}

fn drawGraph(vg: nvg, x: f32, y: f32, w: f32, h: f32, t: f32) void {
    const dx = w / 5.0;

    const samples = [_]f32{
        (1 + @sin(t * 1.2345 + @cos(t * 0.33457) * 0.44)) * 0.5,
        (1 + @sin(t * 0.68363 + @cos(t * 1.3) * 1.55)) * 0.5,
        (1 + @sin(t * 1.1642 + @cos(t * 0.33457) * 1.24)) * 0.5,
        (1 + @sin(t * 0.56345 + @cos(t * 1.63) * 0.14)) * 0.5,
        (1 + @sin(t * 1.6245 + @cos(t * 0.254) * 0.3)) * 0.5,
        (1 + @sin(t * 0.345 + @cos(t * 0.03) * 0.6)) * 0.5,
    };

    var sx: [6]f32 = undefined;
    var sy: [6]f32 = undefined;
    for (samples, 0..) |sample, i| {
        sx[i] = x + @as(f32, @floatFromInt(i)) * dx;
        sy[i] = y + h * sample * 0.8;
    }

    // Graph background
    var bg = vg.linearGradient(x, y, x, y + h, nvg.rgba(0, 160, 192, 0), nvg.rgba(0, 160, 192, 64));
    vg.beginPath();
    vg.moveTo(sx[0], sy[0]);
    var i: u32 = 1;
    while (i < 6) : (i += 1)
        vg.bezierTo(sx[i - 1] + dx * 0.5, sy[i - 1], sx[i] - dx * 0.5, sy[i], sx[i], sy[i]);
    vg.lineTo(x + w, y + h);
    vg.lineTo(x, y + h);
    vg.fillPaint(bg);
    vg.fill();

    // Graph line
    vg.beginPath();
    vg.moveTo(sx[0], sy[0] + 2);
    i = 1;
    while (i < 6) : (i += 1)
        vg.bezierTo(sx[i - 1] + dx * 0.5, sy[i - 1] + 2, sx[i] - dx * 0.5, sy[i] + 2, sx[i], sy[i] + 2);
    vg.strokeColor(nvg.rgba(0, 0, 0, 32));
    vg.strokeWidth(3.0);
    vg.stroke();

    vg.beginPath();
    vg.moveTo(sx[0], sy[0]);

    i = 1;
    while (i < 6) : (i += 1)
        vg.bezierTo(sx[i - 1] + dx * 0.5, sy[i - 1], sx[i] - dx * 0.5, sy[i], sx[i], sy[i]);
    vg.strokeColor(nvg.rgba(0, 160, 192, 255));
    vg.strokeWidth(3.0);
    vg.stroke();

    // Graph sample pos
    i = 0;
    while (i < 6) : (i += 1) {
        bg = vg.radialGradient(sx[i], sy[i] + 2, 3.0, 8.0, nvg.rgba(0, 0, 0, 32), nvg.rgba(0, 0, 0, 0));
        vg.beginPath();
        vg.rect(sx[i] - 10, sy[i] - 10 + 2, 20, 20);
        vg.fillPaint(bg);
        vg.fill();
    }

    vg.beginPath();
    i = 0;
    while (i < 6) : (i += 1)
        vg.circle(sx[i], sy[i], 4.0);
    vg.fillColor(nvg.rgba(0, 160, 192, 255));
    vg.fill();
    vg.beginPath();
    i = 0;
    while (i < 6) : (i += 1)
        vg.circle(sx[i], sy[i], 2.0);
    vg.fillColor(nvg.rgba(220, 220, 220, 255));
    vg.fill();

    vg.strokeWidth(1.0);
}

fn drawSpinner(vg: nvg, cx: f32, cy: f32, r: f32, t: f32) void {
    const a0 = 0.0 + t * 6;
    const a1 = std.math.pi + t * 6;
    const r0 = r;
    const r1 = r * 0.75;

    vg.save();

    vg.beginPath();
    vg.arc(cx, cy, r0, a0, a1, .cw);
    vg.arc(cx, cy, r1, a1, a0, .ccw);
    vg.closePath();
    const ax = cx + @cos(a0) * (r0 + r1) * 0.5;
    const ay = cy + @sin(a0) * (r0 + r1) * 0.5;
    const bx = cx + @cos(a1) * (r0 + r1) * 0.5;
    const by = cy + @sin(a1) * (r0 + r1) * 0.5;
    const paint = vg.linearGradient(ax, ay, bx, by, nvg.rgba(0, 0, 0, 0), nvg.rgba(0, 0, 0, 128));
    vg.fillPaint(paint);
    vg.fill();

    vg.restore();
}

fn drawThumbnails(vg: nvg, x: f32, y: f32, w: f32, h: f32, images: []const nvg.Image, t: f32) void {
    const cornerRadius = 3.0;
    const thumb = 60.0;
    const arry = 30.5;
    const stackh = @as(f32, @floatFromInt(images.len / 2)) * (thumb + 10.0) + 10.0;
    const u = (1 + @cos(t * 0.5)) * 0.5;
    const uu = (1 - @cos(t * 0.2)) * 0.5;

    vg.save();

    // Drop shadow
    var shadowPaint = vg.boxGradient(x, y + 4, w, h, cornerRadius * 2.0, 20, nvg.rgba(0, 0, 0, 128), nvg.rgba(0, 0, 0, 0));
    vg.beginPath();
    vg.rect(x - 10, y - 10, w + 20, h + 30);
    vg.roundedRect(x, y, w, h, cornerRadius);
    vg.pathWinding(nvg.Winding.solidity(.hole));
    vg.fillPaint(shadowPaint);
    vg.fill();

    // Window
    vg.beginPath();
    vg.roundedRect(x, y, w, h, cornerRadius);
    vg.moveTo(x - 10, y + arry);
    vg.lineTo(x + 1, y + arry - 11);
    vg.lineTo(x + 1, y + arry + 11);
    vg.fillColor(nvg.rgba(200, 200, 200, 255));
    vg.fill();

    vg.save();
    vg.scissor(x, y, w, h);
    vg.translate(0, -(stackh - h) * u);

    const dv = 1.0 / @as(f32, @floatFromInt(images.len - 1));

    for (images, 0..) |image, i| {
        var tx = x + 10;
        var ty = y + 10;
        tx += @as(f32, @floatFromInt(i % 2)) * (thumb + 10.0);
        ty += @as(f32, @floatFromInt(i / 2)) * (thumb + 10.0);
        var imgw: u32 = undefined;
        var imgh: u32 = undefined;
        vg.imageSize(image, &imgw, &imgh);
        var ix: f32 = undefined;
        var iy: f32 = undefined;
        var iw: f32 = undefined;
        var ih: f32 = undefined;
        if (imgw < imgh) {
            iw = thumb;
            ih = iw * @as(f32, @floatFromInt(imgh)) / @as(f32, @floatFromInt(imgw));
            ix = 0;
            iy = -(ih - thumb) * 0.5;
        } else {
            ih = thumb;
            iw = ih * @as(f32, @floatFromInt(imgw)) / @as(f32, @floatFromInt(imgh));
            ix = -(iw - thumb) * 0.5;
            iy = 0;
        }

        const v = @as(f32, @floatFromInt(i)) * dv;
        const a = std.math.clamp((uu - v) / dv, 0, 1);

        if (a < 1.0) {
            drawSpinner(vg, tx + thumb / 2.0, ty + thumb / 2.0, thumb * 0.25, t);
        }

        const imgPaint = vg.imagePattern(tx + ix, ty + iy, iw, ih, 0.0 / 180.0 * std.math.pi, image, a);
        vg.beginPath();
        vg.roundedRect(tx, ty, thumb, thumb, 5);
        vg.fillPaint(imgPaint);
        vg.fill();

        shadowPaint = vg.boxGradient(tx - 1, ty, thumb + 2.0, thumb + 2.0, 5, 3, nvg.rgba(0, 0, 0, 128), nvg.rgba(0, 0, 0, 0));
        vg.beginPath();
        vg.rect(tx - 5, ty - 5, thumb + 10.0, thumb + 10.0);
        vg.roundedRect(tx, ty, thumb, thumb, 6);
        vg.pathWinding(nvg.Winding.solidity(.hole));
        vg.fillPaint(shadowPaint);
        vg.fill();

        vg.beginPath();
        vg.roundedRect(tx + 0.5, ty + 0.5, thumb - 1.0, thumb - 1.0, 4 - 0.5);
        vg.strokeWidth(1.0);
        vg.strokeColor(nvg.rgba(255, 255, 255, 192));
        vg.stroke();
    }
    vg.restore();

    // Hide fades
    var fadePaint = vg.linearGradient(x, y, x, y + 6, nvg.rgba(200, 200, 200, 255), nvg.rgba(200, 200, 200, 0));
    vg.beginPath();
    vg.rect(x + 4, y, w - 8, 6);
    vg.fillPaint(fadePaint);
    vg.fill();

    fadePaint = vg.linearGradient(x, y + h, x, y + h - 6, nvg.rgba(200, 200, 200, 255), nvg.rgba(200, 200, 200, 0));
    vg.beginPath();
    vg.rect(x + 4, y + h - 6, w - 8, 6);
    vg.fillPaint(fadePaint);
    vg.fill();

    // Scroll bar
    shadowPaint = vg.boxGradient(x + w - 12 + 1, y + 4 + 1, 8, h - 8, 3, 4, nvg.rgba(0, 0, 0, 32), nvg.rgba(0, 0, 0, 92));
    vg.beginPath();
    vg.roundedRect(x + w - 12, y + 4, 8, h - 8, 3);
    vg.fillPaint(shadowPaint);
    vg.fill();

    const scrollh = (h / stackh) * (h - 8);
    shadowPaint = vg.boxGradient(x + w - 12 - 1, y + 4 + (h - 8 - scrollh) * u - 1, 8, scrollh, 3, 4, nvg.rgba(220, 220, 220, 255), nvg.rgba(128, 128, 128, 255));
    vg.beginPath();
    vg.roundedRect(x + w - 12 + 1, y + 4 + 1 + (h - 8 - scrollh) * u, 8 - 2, scrollh - 2, 2);
    vg.fillPaint(shadowPaint);
    vg.fill();

    vg.restore();
}

fn drawColorwheel(vg: nvg, x: f32, y: f32, w: f32, h: f32, t: f32) void {
    const hue = @sin(t * 0.12);
    var paint: nvg.Paint = undefined;

    vg.save();
    vg.restore();

    const cx = x + w * 0.5;
    const cy = y + h * 0.5;
    const r1 = (if (w < h) w else h) * 0.5 - 5.0;
    const r0 = r1 - 20.0;
    const aeps = 0.5 / r1; // half a pixel arc length in radians (2pi cancels out).

    var i: f32 = 0;
    while (i < 6) : (i += 1) {
        const a0 = i / 6.0 * std.math.pi * 2.0 - aeps;
        const a1 = (i + 1.0) / 6.0 * std.math.pi * 2.0 + aeps;
        vg.beginPath();
        vg.arc(cx, cy, r0, a0, a1, .cw);
        vg.arc(cx, cy, r1, a1, a0, .ccw);
        vg.closePath();
        const ax = cx + @cos(a0) * (r0 + r1) * 0.5;
        const ay = cy + @sin(a0) * (r0 + r1) * 0.5;
        const bx = cx + @cos(a1) * (r0 + r1) * 0.5;
        const by = cy + @sin(a1) * (r0 + r1) * 0.5;
        paint = vg.linearGradient(ax, ay, bx, by, nvg.hsla(a0 / (std.math.pi * 2.0), 1.0, 0.55, 255), nvg.hsla(a1 / (std.math.pi * 2.0), 1.0, 0.55, 255));
        vg.fillPaint(paint);
        vg.fill();
    }

    vg.beginPath();
    vg.circle(cx, cy, r0 - 0.5);
    vg.circle(cx, cy, r1 + 0.5);
    vg.strokeColor(nvg.rgba(0, 0, 0, 64));
    vg.strokeWidth(1.0);
    vg.stroke();

    // Selector
    vg.save();
    vg.translate(cx, cy);
    vg.rotate(hue * std.math.pi * 2);

    // Marker on
    vg.strokeWidth(2.0);
    vg.beginPath();
    vg.rect(r0 - 1, -3, r1 - r0 + 2, 6);
    vg.strokeColor(nvg.rgba(255, 255, 255, 192));
    vg.stroke();

    paint = vg.boxGradient(r0 - 3, -5, r1 - r0 + 6, 10, 2, 4, nvg.rgba(0, 0, 0, 128), nvg.rgba(0, 0, 0, 0));
    vg.beginPath();
    vg.rect(r0 - 2 - 10, -4 - 10, r1 - r0 + 4 + 20, 8 + 20);
    vg.rect(r0 - 2, -4, r1 - r0 + 4, 8);
    vg.pathWinding(nvg.Winding.solidity(.hole));
    vg.fillPaint(paint);
    vg.fill();

    // Center triangle
    const r = r0 - 6;
    var ax = -0.5 * r; // @cos(120.0 / 180.0 * std.math.pi) * r;
    var ay = 0.86602540378 * r; // @sin(120.0 / 180.0 * std.math.pi) * r;
    const bx = -0.5 * r; // @cos(-120.0 / 180.0 * std.math.pi) * r;
    const by = -0.86602540378 * r; // @sin(-120.0 / 180.0 * std.math.pi) * r;
    vg.beginPath();
    vg.moveTo(r, 0);
    vg.lineTo(ax, ay);
    vg.lineTo(bx, by);
    vg.closePath();
    paint = vg.linearGradient(r, 0, ax, ay, nvg.hsla(hue, 1.0, 0.5, 255), nvg.rgba(255, 255, 255, 255));
    vg.fillPaint(paint);
    vg.fill();
    paint = vg.linearGradient((r + ax) * 0.5, (0 + ay) * 0.5, bx, by, nvg.rgba(0, 0, 0, 0), nvg.rgba(0, 0, 0, 255));
    vg.fillPaint(paint);
    vg.fill();
    vg.strokeColor(nvg.rgba(0, 0, 0, 64));
    vg.stroke();

    // Select circle on triangle
    ax = -0.5 * r * 0.3; // @cos(120.0 / 180.0 * std.math.pi) * r * 0.3;
    ay = 0.86602540378 * r * 0.4; // @sin(120.0 / 180.0 * std.math.pi) * r * 0.4;
    vg.strokeWidth(2.0);
    vg.beginPath();
    vg.circle(ax, ay, 5);
    vg.strokeColor(nvg.rgba(255, 255, 255, 192));
    vg.stroke();

    paint = vg.radialGradient(ax, ay, 7, 9, nvg.rgba(0, 0, 0, 64), nvg.rgba(0, 0, 0, 0));
    vg.beginPath();
    vg.rect(ax - 20, ay - 20, 40, 40);
    vg.circle(ax, ay, 7);
    vg.pathWinding(nvg.Winding.solidity(.hole));
    vg.fillPaint(paint);
    vg.fill();

    vg.restore();
}

fn drawLines(vg: nvg, x: f32, y: f32, w: f32, h: f32, t: f32) void {
    _ = h;
    const pad = 5.0;
    const s = w / 9.0 - pad * 2.0;
    const joins = [_]nvg.LineJoin{ .miter, .round, .bevel };
    const caps = [_]nvg.LineCap{ .butt, .round, .square };
    const pts = [_]f32{
        -s * 0.25 + @cos(t * 0.3) * s * 0.5, @sin(t * 0.3) * s * 0.5,
        -s * 0.25,                           0,
        s * 0.25,                            0,
        s * 0.25 + @cos(-t * 0.3) * s * 0.5, @sin(-t * 0.3) * s * 0.5,
    };

    vg.save();
    defer vg.restore();

    for (caps, 0..) |cap, i| {
        for (joins, 0..) |join, j| {
            const fx = x + s * 0.5 + (@as(f32, @floatFromInt(i)) * 3 + @as(f32, @floatFromInt(j))) / 9.0 * w + pad;
            const fy = y - s * 0.5 + pad;

            vg.lineCap(cap);
            vg.lineJoin(join);

            vg.strokeWidth(s * 0.3);
            vg.strokeColor(nvg.rgba(0, 0, 0, 160));
            vg.beginPath();
            vg.moveTo(fx + pts[0], fy + pts[1]);
            vg.lineTo(fx + pts[2], fy + pts[3]);
            vg.lineTo(fx + pts[4], fy + pts[5]);
            vg.lineTo(fx + pts[6], fy + pts[7]);
            vg.stroke();

            vg.lineCap(.butt);
            vg.lineJoin(.bevel);

            vg.strokeWidth(1.0);
            vg.strokeColor(nvg.rgba(0, 192, 255, 255));
            vg.beginPath();
            vg.moveTo(fx + pts[0], fy + pts[1]);
            vg.lineTo(fx + pts[2], fy + pts[3]);
            vg.lineTo(fx + pts[4], fy + pts[5]);
            vg.lineTo(fx + pts[6], fy + pts[7]);
            vg.stroke();
        }
    }
}

fn drawWidths(vg: nvg, x: f32, y0: f32, width: f32) void {
    vg.save();
    defer vg.restore();

    vg.strokeColor(nvg.rgba(0, 0, 0, 255));

    var y = y0;
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        const w = (@as(f32, @floatFromInt(i)) + 0.5) * 0.1;
        vg.strokeWidth(w);
        vg.beginPath();
        vg.moveTo(x, y);
        vg.lineTo(x + width, y + width * 0.3);
        vg.stroke();
        y += 10;
    }
}

fn drawCaps(vg: nvg, x: f32, y: f32, width: f32) void {
    const caps = [_]nvg.LineCap{ .butt, .round, .square };
    const lineWidth = 8.0;

    vg.save();
    defer vg.restore();

    vg.beginPath();
    vg.rect(x - lineWidth / 2.0, y, width + lineWidth, 40);
    vg.fillColor(nvg.rgba(255, 255, 255, 32));
    vg.fill();

    vg.beginPath();
    vg.rect(x, y, width, 40);
    vg.fillColor(nvg.rgba(255, 255, 255, 32));
    vg.fill();

    vg.strokeWidth(lineWidth);
    for (caps, 0..) |cap, i| {
        vg.lineCap(cap);
        vg.strokeColor(nvg.rgba(0, 0, 0, 255));
        vg.beginPath();
        vg.moveTo(x, y + @as(f32, @floatFromInt(i)) * 10 + 5);
        vg.lineTo(x + width, y + @as(f32, @floatFromInt(i)) * 10 + 5);
        vg.stroke();
    }
}

fn drawScissor(vg: nvg, x: f32, y: f32, t: f32) void {
    vg.save();
    defer vg.restore();

    // Draw first rect and set scissor to it's area.
    vg.translate(x, y);
    vg.rotate(nvg.degToRad(5));
    vg.beginPath();
    vg.rect(-20, -20, 60, 40);
    vg.fillColor(nvg.rgba(255, 0, 0, 255));
    vg.fill();
    vg.scissor(-20, -20, 60, 40);

    // Draw second rectangle with offset and rotation.
    vg.translate(40, 0);
    vg.rotate(t);

    // Draw the intended second rectangle without any scissoring.
    vg.save();
    vg.resetScissor();
    vg.beginPath();
    vg.rect(-20, -10, 60, 30);
    vg.fillColor(nvg.rgba(255, 128, 0, 64));
    vg.fill();
    vg.restore();

    // Draw second rectangle with combined scissoring.
    vg.intersectScissor(-20, -10, 60, 30);
    vg.beginPath();
    vg.rect(-20, -10, 60, 30);
    vg.fillColor(nvg.rgba(255, 128, 0, 255));
    vg.fill();
}

fn unpremultiplyAlpha(image: []u8, w: usize, h: usize, stride: usize) void {
    var y: usize = 0;
    while (y < h) : (y += 1) {
        var row = image[y * stride ..][0 .. w * 4];
        var x: usize = 0;
        while (x < w) : (x += 1) {
            defer row = row[4..];
            const r = @as(u32, row[0]);
            const g = @as(u32, row[1]);
            const b = @as(u32, row[2]);
            const a = @as(u32, row[3]);
            if (a != 0) {
                row[0] = @truncate(@min(r * 255 / a, 255));
                row[1] = @truncate(@min(g * 255 / a, 255));
                row[2] = @truncate(@min(b * 255 / a, 255));
            }
        }
    }
}

fn premultiplyAlpha(image: []u8, w: usize, h: usize, stride: usize) void {
    var y: usize = 0;
    while (y < h) : (y += 1) {
        var row = image[y * stride ..][0 .. w * 4];
        var x: usize = 0;
        while (x < w) : (x += 1) {
            defer row = row[4..];
            const r = @as(u32, row[0]);
            const g = @as(u32, row[1]);
            const b = @as(u32, row[2]);
            const a = @as(u32, row[3]);
            if (a != 0) {
                row[0] = @truncate(@min(r * a / 255, 255));
                row[1] = @truncate(@min(g * a / 255, 255));
                row[2] = @truncate(@min(b * a / 255, 255));
            }
        }
    }
}

fn stbiWriteFunc(context: ?*anyopaque, data: ?*anyopaque, size: c_int) callconv(.C) void {
    const buffer: *ArrayList(u8) = @alignCast(@ptrCast(context.?));
    const slice = @as([*]const u8, @ptrCast(data.?))[0..@intCast(size)];
    buffer.appendSlice(slice) catch return;
}

pub fn saveScreenshot(allocator: Allocator, w: i32, h: i32, premult: bool) ![]const u8 {
    const uw: usize = @intCast(w);
    const uh: usize = @intCast(h);
    const stride = uw * 4;
    const image = try allocator.alloc(u8, uw * uh * 4);
    gl.glReadPixels(0, 0, w, h, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, image.ptr);
    if (premult) {
        unpremultiplyAlpha(image, uw, uh, stride);
    } else {
        // Set alpha
        var i: usize = 3;
        while (i < image.len) : (i += 4) {
            image[i] = 0xff;
        }
    }

    // flip vertically
    var y0: usize = 0;
    while (y0 < uh / 2) : (y0 += 1) {
        const y1 = uh - 1 - y0;
        const row0 = image[y0 * stride ..][0..stride];
        const row1 = image[y1 * stride ..][0..stride];
        var x: usize = 0;
        while (x < stride) : (x += 1) {
            std.mem.swap(u8, &row0[x], &row1[x]);
        }
    }

    var buffer = ArrayList(u8).init(allocator);
    errdefer buffer.deinit();
    if (c.stbi_write_png_to_func(stbiWriteFunc, &buffer, w, h, 4, image.ptr, w * 4) == 0) {
        return error.StbiWritePngFailed;
    }
    return buffer.toOwnedSlice();
}
