const std = @import("std");

/// Internal implementation, available for custom backends
pub const internal = @import("internal.zig");

/// OpenGL backend provided by default
pub const gl = @import("nanovg_gl.zig");

const Self = @This();

ctx: *internal.Context,

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const Paint = struct {
    xform: [6]f32,
    extent: [2]f32,
    radius: f32,
    feather: f32,
    blur: [2]f32,
    inner_color: Color,
    outer_color: Color,
    image: Image,
    colormap: Image,
};

pub const Path = struct {
    const Verb = enum {
        move,
        line,
        quad,
        bezier,
        close,
    };
    verbs: []const Verb,
    points: []const f32,
};

pub const Winding = enum(u2) {
    none = 0,
    ccw = 1, // Winding for solid shapes
    cw = 2, // Winding for holes

    pub fn solidity(s: Solidity) Winding {
        return switch (s) {
            .solid => .ccw,
            .hole => .cw,
        };
    }
};

pub const Solidity = enum(u2) {
    solid = 1, // CCW
    hole = 2, // CW
};

pub const LineCap = enum(u2) {
    butt,
    round,
    square,
};

pub const LineJoin = enum(u2) {
    miter,
    round,
    bevel,
};

pub const TextAlign = struct {
    pub const HorizontalAlign = enum(u8) {
        left = 1 << 0,
        center = 1 << 1,
        right = 1 << 2,
        _,
    };
    pub const VerticalAlign = enum(u8) {
        top = 1 << 3,
        middle = 1 << 4,
        bottom = 1 << 5,
        baseline = 1 << 6, // Default, align text vertically to baseline.
        _,
    };

    horizontal: HorizontalAlign = .left,
    vertical: VerticalAlign = .baseline,

    pub fn toInt(text_align: TextAlign) u8 {
        return @intFromEnum(text_align.horizontal) | @intFromEnum(text_align.vertical);
    }
};

pub const BlendFactor = enum(u8) {
    zero,
    one,
    src_color,
    one_minus_src_color,
    dst_color,
    one_minus_dst_color,
    src_alpha,
    one_minus_src_alpha,
    dst_alpha,
    one_minus_dst_alpha,
    src_alpha_saturate,
};

pub const CompositeOperation = enum(u8) {
    source_over,
    source_in,
    source_out,
    atop,
    destination_over,
    destination_in,
    destination_out,
    destination_atop,
    lighter,
    copy,
    xor,
};

pub const CompositeOperationState = struct {
    src_rgb: BlendFactor,
    dst_rgb: BlendFactor,
    src_alpha: BlendFactor,
    dst_alpha: BlendFactor,

    pub fn initOperation(operation: CompositeOperation) CompositeOperationState {
        return switch (operation) {
            .source_over => initFactors(.one, .one_minus_src_alpha),
            .source_in => initFactors(.dst_alpha, .zero),
            .source_out => initFactors(.one_minus_dst_alpha, .zero),
            .atop => initFactors(.dst_alpha, .one_minus_src_alpha),
            .destination_over => initFactors(.one_minus_dst_alpha, .one),
            .destination_in => initFactors(.zero, .src_alpha),
            .destination_out => initFactors(.zero, .one_minus_src_alpha),
            .destination_atop => initFactors(.one_minus_dst_alpha, .src_alpha),
            .lighter => initFactors(.one, .one),
            .copy => initFactors(.one, .zero),
            .xor => initFactors(.one_minus_dst_alpha, .one_minus_src_alpha),
        };
    }

    pub fn initFactors(sfactor: BlendFactor, dfactor: BlendFactor) CompositeOperationState {
        return .{ .src_rgb = sfactor, .dst_rgb = dfactor, .src_alpha = sfactor, .dst_alpha = dfactor };
    }
};

pub const GlyphPosition = struct {
    str: [*]const u8, // Position of the glyph in the input string.
    x: f32, // The x-coordinate of the logical glyph position.
    minx: f32,
    maxx: f32, // The bounds of the glyph shape.
};

pub const TextRow = struct {
    text: []const u8,
    next: []const u8,
    width: f32,
    minx: f32,
    maxx: f32,
};

pub const Image = struct {
    handle: i32,
};

pub const ImageFlags = packed struct {
    generate_mipmaps: bool = false, // Generate mipmaps during creation of the image.
    repeat_x: bool = false, // Repeat image in X direction.
    repeat_y: bool = false, // Repeat image in Y direction.
    flip_y: bool = false, // Flips (inverses) image in Y direction when rendered.
    premultiplied: bool = false, // Image data has premultiplied alpha.
    nearest: bool = false, // Image interpolation is Nearest instead Linear
};

pub const Font = struct {
    handle: i32,
};

pub fn deinit(self: Self) void {
    self.ctx.deinit();
}

// Begin drawing a new frame
// Calls to nanovg drawing API should be wrapped in nvgBeginFrame() & nvgEndFrame()
// nvgBeginFrame() defines the size of the window to render to in relation currently
// set viewport (i.e. glViewport on GL backends). Device pixel ration allows to
// control the rendering on Hi-DPI devices.
// For example, GLFW returns two dimension for an opened window: window size and
// frame buffer size. In that case you would set windowWidth/Height to the window size
// devicePixelRatio to: frameBufferWidth / windowWidth.
pub fn beginFrame(self: Self, window_width: f32, window_height: f32, device_pixel_ratio: f32) void {
    self.ctx.beginFrame(window_width, window_height, device_pixel_ratio);
}

// Cancels drawing the current frame.
pub fn cancelFrame(self: Self) void {
    self.ctx.cancelFrame();
}

// Ends drawing flushing remaining render state.
pub fn endFrame(self: Self) void {
    self.ctx.endFrame();
}

//
// Composite operation
//
// The composite operations in NanoVG are modeled after HTML Canvas API, and
// the blend func is based on OpenGL (see corresponding manuals for more info).
// The colors in the blending state have premultiplied alpha.

// Sets the composite operation. The op parameter should be one of NVGcompositeOperation.
pub fn globalCompositeOperation(self: Self, op: CompositeOperation) void {
    self.ctx.getState().composite_operation = CompositeOperationState.initOperation(op);
}

// Sets the composite operation with custom pixel arithmetic. The parameters should be one of NVGblendFactor.
pub fn globalCompositeBlendFunc(self: Self, sfactor: BlendFactor, dfactor: BlendFactor) void {
    self.globalCompositeBlendFuncSeparate(sfactor, dfactor, sfactor, dfactor, sfactor);
}

// Sets the composite operation with custom pixel arithmetic for RGB and alpha components separately. The parameters should be one of NVGblendFactor.
pub fn globalCompositeBlendFuncSeparate(self: Self, srcRGB: BlendFactor, dstRGB: BlendFactor, srcAlpha: BlendFactor, dstAlpha: BlendFactor) void {
    self.ctx.getState().compositeOperation = .{
        .src_rgb = srcRGB,
        .dst_rgb = dstRGB,
        .src_alpha = srcAlpha,
        .dst_alpha = dstAlpha,
    };
}

//
// Color utils
//
// Colors in NanoVG are stored as unsigned ints in ABGR format.

// Returns a color value from red, green, blue values. Alpha will be set to 255 (1.0f).
pub fn rgb(r: u8, g: u8, b: u8) Color {
    return rgbf(
        @as(f32, @floatFromInt(r)) / 255.0,
        @as(f32, @floatFromInt(g)) / 255.0,
        @as(f32, @floatFromInt(b)) / 255.0,
    );
}

// Returns a color value from red, green, blue values. Alpha will be set to 1.0f.
pub fn rgbf(r: f32, g: f32, b: f32) Color {
    return rgbaf(r, g, b, 1);
}

// Returns a color value from red, green, blue and alpha values.
pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
    return rgbaf(
        @as(f32, @floatFromInt(r)) / 255.0,
        @as(f32, @floatFromInt(g)) / 255.0,
        @as(f32, @floatFromInt(b)) / 255.0,
        @as(f32, @floatFromInt(a)) / 255.0,
    );
}

// Returns a color value from red, green, blue and alpha values.
pub fn rgbaf(r: f32, g: f32, b: f32, a: f32) Color {
    return .{ .r = r, .g = g, .b = b, .a = a };
}

// // Linearly interpolates from color c0 to c1, and returns resulting color value.
pub fn lerpRGBA(c0: Color, c1: Color, u: f32) Color {
    const a = std.math.clamp(u, 0, 1);
    const oma = 1 - a;
    return .{
        .r = a * c0.r + oma * c1.r,
        .g = a * c0.g + oma * c1.g,
        .b = a * c0.b + oma * c1.b,
        .a = a * c0.a + oma * c1.a,
    };
}

// // Sets transparency of a color value.
// NVGcolor nvgTransRGBA(NVGcolor c0, unsigned char a);
pub fn transRGBA(c0: Color, a: u8) Color {
    return transRGBAf(c0, @as(f32, @floatFromInt(a)) / 255.0);
}

// // Sets transparency of a color value.
// NVGcolor nvgTransRGBAf(NVGcolor c0, float a);
pub fn transRGBAf(c0: Color, a: f32) Color {
    return .{
        .r = c0.r,
        .g = c0.g,
        .b = c0.b,
        .a = a,
    };
}

// Returns color value specified by hue, saturation and lightness.
// HSL values are all in range [0..1], alpha will be set to 255.
// NVGcolor nvgHSL(float h, float s, float l);
pub fn hsl(hue: f32, sat: f32, lig: f32) Color {
    return hsla(hue, sat, lig, 255);
}

// Returns color value specified by hue, saturation and lightness and alpha.
// HSL values are all in range [0..1], alpha in range [0..255]
pub fn hsla(hue: f32, sat: f32, lig: f32, a: u8) Color {
    var h = @mod(hue, 1.0);
    if (h < 0.0) h += 1.0;
    const s = std.math.clamp(sat, 0, 1);
    const l = std.math.clamp(lig, 0, 1);
    const m2 = if (l <= 0.5) l * (1 + s) else l + s - l * s;
    const m1 = 2 * l - m2;
    return .{
        .r = std.math.clamp(getHue(h + 1.0 / 3.0, m1, m2), 0, 1),
        .g = std.math.clamp(getHue(h, m1, m2), 0, 1),
        .b = std.math.clamp(getHue(h - 1.0 / 3.0, m1, m2), 0, 1),
        .a = @as(f32, @floatFromInt(a)) / 255.0,
    };
}
fn getHue(hue: f32, m1: f32, m2: f32) f32 {
    var h = hue;
    if (h < 0) h += 1;
    if (h > 1) h -= 1;
    if (h < 1.0 / 6.0) {
        return m1 + (m2 - m1) * h * 6.0;
    } else if (h < 3.0 / 6.0) {
        return m2;
    } else if (h < 4.0 / 6.0) {
        return m1 + (m2 - m1) * (2.0 / 3.0 - h) * 6.0;
    }
    return m1;
}

//
// State Handling
//
// NanoVG contains state which represents how paths will be rendered.
// The state contains transform, fill and stroke styles, text and font styles,
// and scissor clipping.

// Pushes and saves the current render state into a state stack.
// A matching nvgRestore() must be used to restore the state.
pub fn save(self: Self) void {
    self.ctx.save();
}

// Pops and restores current render state.
pub fn restore(self: Self) void {
    self.ctx.restore();
}

// Resets current render state to default values. Does not affect the render state stack.
pub fn reset(self: Self) void {
    self.ctx.reset();
}

//
// Render styles
//
// Fill and stroke render style can be either a solid color or a paint which is a gradient or a pattern.
// Solid color is simply defined as a color value, different kinds of paints can be created
// using nvgLinearGradient(), nvgBoxGradient(), nvgRadialGradient() and nvgImagePattern().
//
// Current render style can be saved and restored using nvgSave() and nvgRestore().

// // Sets current stroke style to a solid color.
pub fn strokeColor(self: Self, color: Color) void {
    self.ctx.strokeColor(color);
}

// Sets current stroke style to a paint, which can be a one of the gradients or a pattern.
pub fn strokePaint(self: Self, paint: Paint) void {
    self.ctx.strokePaint(paint);
}

// Sets current fill style to a solid color.
pub fn fillColor(self: Self, color: Color) void {
    self.ctx.fillColor(color);
}

// Sets current fill style to a paint, which can be a one of the gradients or a pattern.
pub fn fillPaint(self: Self, paint: Paint) void {
    self.ctx.fillPaint(paint);
}

// Sets the miter limit of the stroke style.
// Miter limit controls when a sharp corner is beveled.
pub fn miterLimit(self: Self, limit: f32) void {
    self.ctx.miterLimit(limit);
}

// // Sets the stroke width of the stroke style.
pub fn strokeWidth(self: Self, size: f32) void {
    self.ctx.strokeWidth(size);
}

// Sets how the end of the line (cap) is drawn,
// Can be one of: NVG_BUTT (default), NVG_ROUND, NVG_SQUARE.
pub fn lineCap(self: Self, cap: LineCap) void {
    self.ctx.lineCap(cap);
}

// Sets how sharp path corners are drawn.
// Can be one of NVG_MITER (default), NVG_ROUND, NVG_BEVEL.
pub fn lineJoin(self: Self, join: LineJoin) void {
    self.ctx.lineJoin(join);
}

// Sets the transparency applied to all rendered shapes.
// Already transparent paths will get proportionally more transparent as well.
pub fn globalAlpha(self: Self, alpha: f32) void {
    self.ctx.globalAlpha(alpha);
}

//
// Transforms
//
// The paths, gradients, patterns and scissor region are transformed by an transformation
// matrix at the time when they are passed to the API.
// The current transformation matrix is a affine matrix:
//   [sx kx tx]
//   [ky sy ty]
//   [ 0  0  1]
// Where: sx,sy define scaling, kx,ky skewing, and tx,ty translation.
// The last row is assumed to be 0,0,1 and is not stored.
//
// Apart from nvgResetTransform(), each transformation function first creates
// specific transformation matrix and pre-multiplies the current transformation by it.
//
// Current coordinate system (transformation) can be saved and restored using nvgSave() and nvgRestore().

// Resets current transform to a identity matrix.
pub fn resetTransform(self: Self) void {
    self.ctx.resetTransform();
}

// Premultiplies current coordinate system by specified matrix.
// The parameters are interpreted as matrix as follows:
//   [a c e]
//   [b d f]
//   [0 0 1]
pub fn transform(self: Self, a: f32, b: f32, c: f32, d: f32, e: f32, f: f32) void {
    self.ctx.transform(a, b, c, d, e, f);
}

// Translates current coordinate system.
pub fn translate(self: Self, x: f32, y: f32) void {
    self.ctx.translate(x, y);
}

// Rotates current coordinate system. Angle is specified in radians.
pub fn rotate(self: Self, angle: f32) void {
    self.ctx.rotate(angle);
}

// Skews the current coordinate system along X axis. Angle is specified in radians.
pub fn skewX(self: Self, angle: f32) void {
    self.ctx.skewX(angle);
}

// Skews the current coordinate system along Y axis. Angle is specified in radians.
pub fn skewY(self: Self, angle: f32) void {
    self.ctx.skewY(angle);
}

// Scales the current coordinate system.
pub fn scale(self: Self, x: f32, y: f32) void {
    self.ctx.scale(x, y);
}

// Stores the top part (a-f) of the current transformation matrix in to the specified buffer.
//   [a c e]
//   [b d f]
//   [0 0 1]
// There should be space for 6 floats in the return buffer for the values a-f.
pub fn currentTransform(self: Self, xform: *[6]f32) void {
    self.ctx.currentTransform(xform);
}

// The following functions can be used to make calculations on 2x3 transformation matrices.
// A 2x3 matrix is represented as float[6].

// Sets the transform to identity matrix.
pub fn transformIdentity(t: *[6]f32) void {
    t[0] = 1;
    t[1] = 0;
    t[2] = 0;
    t[3] = 1;
    t[4] = 0;
    t[5] = 0;
}

// Sets the transform to translation matrix matrix.
pub fn transformTranslate(dst: *[6]f32, tx: f32, ty: f32) void {
    const t = dst;
    t[0] = 1;
    t[1] = 0;
    t[2] = 0;
    t[3] = 1;
    t[4] = tx;
    t[5] = ty;
}

// Sets the transform to scale matrix.
pub fn transformScale(dst: *[6]f32, sx: f32, sy: f32) void {
    const t = dst;
    t[0] = sx;
    t[1] = 0;
    t[2] = 0;
    t[3] = sy;
    t[4] = 0;
    t[5] = 0;
}

// Sets the transform to rotate matrix. Angle is specified in radians.
pub fn transformRotate(dst: *[6]f32, a: f32) void {
    const t = dst;
    const c = @cos(a);
    const s = @sin(a);
    t[0] = c;
    t[1] = s;
    t[2] = -s;
    t[3] = c;
    t[4] = 0;
    t[5] = 0;
}

// Sets the transform to skew-x matrix. Angle is specified in radians.
pub fn transformSkewX(dst: *[6]f32, a: f32) void {
    const t = dst;
    t[0] = 1;
    t[1] = 0;
    t[2] = @tan(a);
    t[3] = 1;
    t[4] = 0;
    t[5] = 0;
}

// Sets the transform to skew-y matrix. Angle is specified in radians.
pub fn transformSkewY(dst: *[6]f32, a: f32) void {
    const t = dst;
    t[0] = 1;
    t[1] = @tan(a);
    t[2] = 0;
    t[3] = 1;
    t[4] = 0;
    t[5] = 0;
}

// Sets the transform to the result of multiplication of two transforms, of A = A*B.
pub fn transformMultiply(dst: *[6]f32, src: *const [6]f32) void {
    const t = dst;
    const s = src;
    const t0 = t[0] * s[0] + t[1] * s[2];
    const t2 = t[2] * s[0] + t[3] * s[2];
    const t4 = t[4] * s[0] + t[5] * s[2] + s[4];
    t[1] = t[0] * s[1] + t[1] * s[3];
    t[3] = t[2] * s[1] + t[3] * s[3];
    t[5] = t[4] * s[1] + t[5] * s[3] + s[5];
    t[0] = t0;
    t[2] = t2;
    t[4] = t4;
}

// // Sets the transform to the result of multiplication of two transforms, of A = B*A.
pub fn transformPremultiply(dst: *[6]f32, src: *const [6]f32) void {
    const t = dst;
    const s = src;
    var tmp: [6]f32 = undefined;
    @memcpy(&tmp, s);
    transformMultiply(&tmp, t);
    @memcpy(t, &tmp);
}

// Sets the destination to inverse of specified transform.
// Returns 1 if the inverse could be calculated, else 0.
pub fn transformInverse(dst: *[6]f32, src: *const [6]f32) bool {
    const inv = dst;
    const t = src;
    const det: f64 = t[0] * t[3] - t[2] * t[1];
    if (det > -1e-6 and det < 1e-6) {
        transformIdentity(inv);
        return false;
    }
    const invdet = 1.0 / det;
    inv[0] = @floatCast(t[3] * invdet);
    inv[2] = @floatCast(-t[2] * invdet);
    inv[4] = @floatCast((t[2] * t[5] - t[3] * t[4]) * invdet);
    inv[1] = @floatCast(-t[1] * invdet);
    inv[3] = @floatCast(t[0] * invdet);
    inv[5] = @floatCast((t[1] * t[4] - t[0] * t[5]) * invdet);
    return true;
}

// Transform a point by given transform.
pub fn transformPoint(dstx: *f32, dsty: *f32, xform: *const [6]f32, srcx: f32, srcy: f32) void {
    const t = xform;
    dstx.* = srcx * t[0] + srcy * t[2] + t[4];
    dsty.* = srcx * t[1] + srcy * t[3] + t[5];
}

// Converts degrees to radians and vice versa.
pub fn degToRad(deg: f32) f32 {
    return deg / 180.0 * std.math.pi;
}
pub fn radToDeg(rad: f32) f32 {
    return rad / std.math.pi * 180.0;
}

//
// Images
//
// NanoVG allows you to load jpg, png, psd, tga, pic and gif files to be used for rendering.
// In addition you can upload your own image. The image loading is provided by stb_image.
// The parameter imageFlags is combination of flags defined in NVGimageFlags.

// // Creates image by loading it from the disk from specified file name.
// // Returns handle to the image.
// pub fn createImage(filename: [:0]const u8, flags: ImageFlags) Image {
//     return Image{ .handle = c.nvgCreateImage(ctx, filename.ptr, @bitCast(u6, flags)) };
// }

// Creates image by loading it from the specified chunk of memory.
// Returns handle to the image.
pub fn createImageMem(self: Self, data: []const u8, flags: ImageFlags) Image {
    return self.ctx.createImageMem(data, flags);
}

// Creates image from specified image data.
// Returns handle to the image.
pub fn createImageRGBA(self: Self, w: u32, h: u32, flags: ImageFlags, data: ?[]const u8) Image {
    return self.ctx.createImageRGBA(w, h, flags, data);
}

// Creates alpha image from specified image data.
// Returns handle to the image.
pub fn createImageAlpha(self: Self, w: u32, h: u32, flags: ImageFlags, data: []const u8) Image {
    return self.ctx.createImageAlpha(w, h, flags, data);
}

// Updates image data specified by image handle.
pub fn updateImage(self: Self, image: Image, data: []const u8) void {
    self.ctx.updateImage(image, data);
}

// Returns the dimensions of a created image.
pub fn imageSize(self: Self, image: Image, w: *u32, h: *u32) void {
    self.ctx.imageSize(image.handle, w, h);
}

// Deletes created image.
pub fn deleteImage(self: Self, image: Image) void {
    self.ctx.deleteImage(image.handle);
}

//
// Paints
//
// NanoVG supports four types of paints: linear gradient, box gradient, radial gradient and image pattern.
// These can be used as paints for strokes and fills.

// Creates and returns a linear gradient. Parameters (sx,sy)-(ex,ey) specify the start and end coordinates
// of the linear gradient, icol specifies the start color and ocol the end color.
// The gradient is transformed by the current transform when it is passed to nvgFillPaint() or nvgStrokePaint().
pub fn linearGradient(self: Self, sx: f32, sy: f32, ex: f32, ey: f32, icol: Color, ocol: Color) Paint {
    return self.ctx.linearGradient(sx, sy, ex, ey, icol, ocol);
}

// Creates and returns a box gradient. Box gradient is a feathered rounded rectangle, it is useful for rendering
// drop shadows or highlights for boxes. Parameters (x,y) define the top-left corner of the rectangle,
// (w,h) define the size of the rectangle, r defines the corner radius, and f feather. Feather defines how blurry
// the border of the rectangle is. Parameter icol specifies the inner color and ocol the outer color of the gradient.
// The gradient is transformed by the current transform when it is passed to nvgFillPaint() or nvgStrokePaint().
pub fn boxGradient(self: Self, x: f32, y: f32, w: f32, h: f32, r: f32, f: f32, icol: Color, ocol: Color) Paint {
    return self.ctx.boxGradient(x, y, w, h, r, f, icol, ocol);
}

// Creates and returns a radial gradient. Parameters (cx,cy) specify the center, inr and outr specify
// the inner and outer radius of the gradient, icol specifies the start color and ocol the end color.
// The gradient is transformed by the current transform when it is passed to nvgFillPaint() or nvgStrokePaint().
pub fn radialGradient(self: Self, cx: f32, cy: f32, inr: f32, outr: f32, icol: Color, ocol: Color) Paint {
    return self.ctx.radialGradient(cx, cy, inr, outr, icol, ocol);
}

// Creates and returns an image pattern. Parameters (ox,oy) specify the left-top location of the image pattern,
// (ex,ey) the size of one image, angle rotation around the top-left corner, image is a handle to the image to render.
// The gradient is transformed by the current transform when it is passed to nvgFillPaint() or nvgStrokePaint().
pub fn imagePattern(self: Self, ox: f32, oy: f32, ex: f32, ey: f32, angle: f32, image: Image, alpha: f32) Paint {
    return self.ctx.imagePattern(ox, oy, ex, ey, angle, image, alpha);
}

// Creates and returns an image pattern.
// (ex,ey) the size of one image. image is a handle to the image to render.
// (blur_x,blur_y) control the blur direction. Only either can be 1.
pub fn imageBlur(self: Self, ex: f32, ey: f32, image: Image, blur_x: f32, blur_y: f32) Paint {
    return self.ctx.imageBlur(ex, ey, image, blur_x, blur_y);
}

// Creates and returns an image pattern. Parameters (ox,oy) specify the left-top location of the image pattern,
// (ex,ey) the size of one image, angle rotation around the top-left corner, image is a handle to the image to render.
// The image contains indices into the colormap, which is also a handle to an image and contains up to 256 colors.
// The gradient is transformed by the current transform when it is passed to nvgFillPaint() or nvgStrokePaint().
pub fn indexedImagePattern(self: Self, ox: f32, oy: f32, ex: f32, ey: f32, angle: f32, image: Image, colormap: Image, alpha: f32) Paint {
    return self.ctx.indexedImagePattern(ox, oy, ex, ey, angle, image, colormap, alpha);
}

//
// Scissoring
//
// Scissoring allows you to clip the rendering into a rectangle. This is useful for various
// user interface cases like rendering a text edit or a timeline.

// Sets the current scissor rectangle.
// The scissor rectangle is transformed by the current transform.
pub fn scissor(self: Self, x: f32, y: f32, w: f32, h: f32) void {
    self.ctx.scissor(x, y, w, h);
}

// Intersects current scissor rectangle with the specified rectangle.
// The scissor rectangle is transformed by the current transform.
// Note: in case the rotation of previous scissor rect differs from
// the current one, the intersection will be done between the specified
// rectangle and the previous scissor rectangle transformed in the current
// transform space. The resulting shape is always rectangle.
pub fn intersectScissor(self: Self, x: f32, y: f32, w: f32, h: f32) void {
    self.ctx.intersectScissor(x, y, w, h);
}

// Reset and disables scissoring.
pub fn resetScissor(self: Self) void {
    self.ctx.resetScissor();
}

//
// Paths
//
// Drawing a new shape starts with nvgBeginPath(), it clears all the currently defined paths.
// Then you define one or more paths and sub-paths which describe the shape. The are functions
// to draw common shapes like rectangles and circles, and lower level step-by-step functions,
// which allow to define a path curve by curve.
//
// NanoVG uses even-odd fill rule to draw the shapes. Solid shapes should have counter clockwise
// winding and holes should have counter clockwise order. To specify winding of a path you can
// call nvgPathWinding(). This is useful especially for the common shapes, which are drawn CCW.
//
// Finally you can fill the path using current fill style by calling nvgFill(), and stroke it
// with current stroke style by calling nvgStroke().
//
// The curve segments and sub-paths are transformed by the current transform.

// Clears the current path and sub-paths.
pub fn beginPath(self: Self) void {
    self.ctx.beginPath();
}

// Adds a path consisting of multiple verbs and corresponding point data.
pub fn addPath(self: Self, path: Path) void {
    self.ctx.addPath(path);
}

// Starts new sub-path with specified point as first point.
pub fn moveTo(self: Self, x: f32, y: f32) void {
    self.ctx.moveTo(x, y);
}

// Adds line segment from the last point in the path to the specified point.
pub fn lineTo(self: Self, x: f32, y: f32) void {
    self.ctx.lineTo(x, y);
}

// Adds cubic bezier segment from last point in the path via two control points to the specified point.
pub fn bezierTo(self: Self, c1x: f32, c1y: f32, c2x: f32, c2y: f32, x: f32, y: f32) void {
    self.ctx.bezierTo(c1x, c1y, c2x, c2y, x, y);
}

// Adds quadratic bezier segment from last point in the path via a control point to the specified point.
pub fn quadTo(self: Self, cx: f32, cy: f32, x: f32, y: f32) void {
    self.ctx.quadTo(cx, cy, x, y);
}

// Adds an arc segment at the corner defined by the last path point, and two specified points.
pub fn arcTo(self: Self, x1: f32, y1: f32, x2: f32, y2: f32, r: f32) void {
    self.ctx.arcTo(x1, y1, x2, y2, r);
}

// Closes current sub-path with a line segment.
pub fn closePath(self: Self) void {
    self.ctx.closePath();
}

// Sets the current sub-path winding, see NVGwinding and NVGsolidity.
pub fn pathWinding(self: Self, dir: Winding) void {
    self.ctx.pathWinding(dir);
}

// Creates new circle arc shaped sub-path. The arc center is at cx,cy, the arc radius is r,
// and the arc is drawn from angle a0 to a1, and swept in direction dir (NVG_CCW, or NVG_CW).
// Angles are specified in radians.
pub fn arc(self: Self, cx: f32, cy: f32, r: f32, a0: f32, a1: f32, dir: Winding) void {
    self.ctx.arc(cx, cy, r, a0, a1, dir);
}

// Creates new rectangle shaped sub-path.
pub fn rect(self: Self, x: f32, y: f32, w: f32, h: f32) void {
    self.ctx.rect(x, y, w, h);
}

// Creates new rounded rectangle shaped sub-path.
pub fn roundedRect(self: Self, x: f32, y: f32, w: f32, h: f32, r: f32) void {
    self.ctx.roundedRect(x, y, w, h, r);
}

// Creates new rounded rectangle shaped sub-path with varying radii for each corner.
pub fn roundedRectVarying(self: Self, x: f32, y: f32, w: f32, h: f32, radTopLeft: f32, radTopRight: f32, radBottomRight: f32, radBottomLeft: f32) void {
    self.ctx.roundedRectVarying(x, y, w, h, radTopLeft, radTopRight, radBottomRight, radBottomLeft);
}

// Creates new ellipse shaped sub-path.
pub fn ellipse(self: Self, cx: f32, cy: f32, rx: f32, ry: f32) void {
    self.ctx.ellipse(cx, cy, rx, ry);
}

// Creates new circle shaped sub-path.
pub fn circle(self: Self, cx: f32, cy: f32, r: f32) void {
    self.ctx.ellipse(cx, cy, r, r);
}

// Use all previously recorded paths since beginPath as clip path.
pub fn clip(self: Self) void {
    self.ctx.clip();
}

// Fills the current path with current fill style.
pub fn fill(self: Self) void {
    self.ctx.fill();
}

// Fills the current path with current stroke style.
pub fn stroke(self: Self) void {
    self.ctx.stroke();
}

//
// Text
//
// NanoVG allows you to load .ttf files and use the font to render text.
//
// The appearance of the text can be defined by setting the current text style
// and by specifying the fill color. Common text and font settings such as
// font size, letter spacing and text align are supported. Font blur allows you
// to create simple text effects such as drop shadows.
//
// At render time the font face can be set based on the font handles or name.
//
// Font measure functions return values in local space, the calculations are
// carried in the same resolution as the final rendering. This is done because
// the text glyph positions are snapped to the nearest pixels sharp rendering.
//
// The local space means that values are not rotated or scale as per the current
// transformation. For example if you set font size to 12, which would mean that
// line height is 16, then regardless of the current scaling and rotation, the
// returned line height is always 16. Some measures may vary because of the scaling
// since aforementioned pixel snapping.
//
// While this may sound a little odd, the setup allows you to always render the
// same way regardless of scaling. I.e. following works regardless of scaling:
//
//          const char* txt = "Text me up.";
//          nvgTextBounds(vg, x,y, txt, NULL, bounds);
//          nvgBeginPath(vg);
//          nvgRoundedRect(vg, bounds[0],bounds[1], bounds[2]-bounds[0], bounds[3]-bounds[1]);
//          nvgFill(vg);
//
// Note: currently only solid color fill is supported for text.

// // Creates font by loading it from the disk from specified file name.
// // Returns handle to the font.
// pub fn createFont(name: [:0]const u8, filename: [:0]const u8) Font {
//     return Font{ .handle = c.nvgCreateFont(ctx, name, filename) };
// }

// // font_index specifies which font face to load from a .ttf/.ttc file.
// pub fn createFontAtIndex(name: [:0]const u8, filename: [:0]const u8, font_index: i32) Font {
//     return Font{ .handle = c.nvgCreateFontAtIndex(ctx, name, filename, font_index) };
// }

// Creates font by loading it from the specified memory chunk.
// Returns handle to the font.
pub fn createFontMem(self: Self, name: [:0]const u8, data: []const u8) Font {
    return Font{ .handle = self.ctx.createFontMem(name, data) };
}

// // // fontIndex specifies which font face to load from a .ttf/.ttc file.
// // int nvgCreateFontMemAtIndex(NVGcontext* ctx, const char* name, unsigned char* data, int ndata, int freeData, const int fontIndex);

// // // Finds a loaded font of specified name, and returns handle to it, or -1 if the font is not found.
// // int nvgFindFont(NVGcontext* ctx, const char* name);

// Adds a fallback font by handle.
pub fn addFallbackFontId(self: Self, base_font: Font, fallback_font: Font) bool {
    return self.ctx.addFallbackFontId(base_font, fallback_font);
}

// // Adds a fallback font by name.
// int nvgAddFallbackFont(NVGcontext* ctx, const char* baseFont, const char* fallbackFont);

// // Resets fallback fonts by handle.
// void nvgResetFallbackFontsId(NVGcontext* ctx, int baseFont);

// // Resets fallback fonts by name.
// void nvgResetFallbackFonts(NVGcontext* ctx, const char* baseFont);

// Sets the font size of current text style.
pub fn fontSize(self: Self, size: f32) void {
    self.ctx.fontSize(size);
}

// Sets the blur of current text style.
pub fn fontBlur(self: Self, blur: f32) void {
    self.ctx.fontBlur(blur);
}

// Sets the letter spacing of current text style.
pub fn textLetterSpacing(self: Self, spacing: f32) void {
    self.ctx.textLetterSpacing(spacing);
}

// Sets the proportional line height of current text style. The line height is specified as multiple of font size.
pub fn textLineHeight(self: Self, line_height: f32) void {
    self.ctx.textLineHeight(line_height);
}

// Sets the text align of current text style, see NVGalign for options.
pub fn textAlign(self: Self, text_align: TextAlign) void {
    self.ctx.textAlign(text_align);
}

// Sets the font face based on specified id of current text style.
pub fn fontFaceId(self: Self, font: Font) void {
    self.ctx.fontFaceId(font);
}

// Sets the font face based on specified name of current text style.
pub fn fontFace(self: Self, font: [:0]const u8) void {
    self.ctx.fontFace(font);
}

// Draws text string at specified location. If end is specified only the sub-string up to the end is drawn.
pub fn text(self: Self, x: f32, y: f32, string: []const u8) f32 {
    if (string.len == 0) return x;
    return self.ctx.text(x, y, string);
}

// Draws multi-line text string at specified location wrapped at the specified width. If end is specified only the sub-string up to the end is drawn.
// White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
// Words longer than the max width are slit at nearest character (i.e. no hyphenation).
pub fn textBox(self: Self, x: f32, y: f32, break_row_width: f32, string: []const u8) void {
    self.ctx.textBox(x, y, break_row_width, string);
}

// Measures the specified text string. Parameter bounds should be a pointer to float[4],
// if the bounding box of the text should be returned. The bounds value are [xmin,ymin, xmax,ymax]
// Returns the horizontal advance of the measured text (i.e. where the next character should drawn).
// Measured values are returned in local coordinate space.
pub fn textBounds(self: Self, x: f32, y: f32, string: []const u8, bounds: ?*[4]f32) f32 {
    return self.ctx.textBounds(x, y, string, bounds);
}

// Measures the specified multi-text string. Parameter bounds should be a pointer to float[4],
// if the bounding box of the text should be returned. The bounds value are [xmin,ymin, xmax,ymax]
// Measured values are returned in local coordinate space.
pub fn textBoxBounds(self: Self, x: f32, y: f32, break_row_width: f32, string: []const u8, bounds: ?*[4]f32) void {
    self.ctx.textBoxBounds(x, y, break_row_width, string, bounds);
}

// Calculates the glyph x positions of the specified text. If end is specified only the sub-string will be used.
// Measured values are returned in local coordinate space.
pub fn textGlyphPositions(self: Self, x: f32, y: f32, string: []const u8, positions: []GlyphPosition) usize {
    return self.ctx.textGlyphPositions(x, y, string, positions);
}

// Returns the vertical metrics based on the current text style.
// Measured values are returned in local coordinate space.
pub fn textMetrics(self: Self, ascender: ?*f32, descender: ?*f32, line_height: ?*f32) void {
    self.ctx.textMetrics(ascender, descender, line_height);
}

// Breaks the specified text into lines. If end is specified only the sub-string will be used.
// White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
// Words longer than the max width are slit at nearest character (i.e. no hyphenation).
pub fn textBreakLines(self: Self, string: []const u8, break_row_width: f32, rows: []TextRow) usize {
    return self.ctx.textBreakLines(string, break_row_width, rows);
}
