NanoVG - Zig Version
==========

This is a rewrite of the original [NanoVG library](https://github.com/memononen/nanovg) using the [Zig programming language](https://ziglang.org).

NanoVG is a small anti-aliased hardware-accelerated vector graphics library. It has a lean API modeled after the HTML5 canvas API. It is aimed to be a practical and fun toolset for building scalable user interfaces or any other real time visualizations.

## Screenshot

![screenshot of some text rendered with the example program](/examples/screenshot-01.png?raw=true)

## Examples

There's a WebAssembly example using WebGL which you can immediately try here: https://fabioarnold.github.io/nanovg-zig. The source for this example can be found in [example_wasm.zig](/examples/example_wasm.zig) and can be built by running `zig build -Dtarget=wasm32-freestanding`.

A native cross-platform example using [GLFW](https://glfw.org) can be found in [example_glfw.zig](/examples/example_glfw.zig) and can be built and run with `zig build run`. It requires GLFW to be installed. On Windows [vcpkg](https://github.com/microsoft/vcpkg) is an additional requirement.

For an example on how to use nanovg-zig in your project's `build.zig` you can take a look at https://github.com/fabioarnold/MiniPixel/blob/main/build.zig.

## Features

* Basic shapes: rect, rounded rect, ellipse, arc
* Arbitrary paths of bezier curves with holes
* Arbitrary stack-based 2D transforms
* Strokes with different types of caps and joins
* Fills with gradient support
* Types of gradients: linear, box (useful for shadows), radial
* Text with automatic linebreaks and blurring
* Images as pattern for fills and strokes

### Features exclusive to the Zig version

* Clip paths
* Image blurring

Usage
=====

The NanoVG API is modeled loosely on the HTML5 canvas API. If you know canvas, you're up to speed with NanoVG in no time.

## Creating a drawing context

The drawing context is created using a backend-specific initialization function. If you're using the OpenGL backend the context is created as follows:
```zig
const nvg = @import("nanovg");
...
var vg = try nvg.gl.init(allocator, .{
	.debug = true,
});
defer vg.deinit();
```

The second parameter defines options for creating the renderer.

- `antialias` means that the renderer adjusts the geometry to include anti-aliasing. If you're using MSAA, you can omit this option to be default initialized as false. 
- `stencil_strokes` means that the render uses better quality rendering for (overlapping) strokes. The quality is mostly visible on wider strokes. If you want speed, you can omit this option to be default initialized as false.

Currently, there is an OpenGL backend for NanoVG: [nanovg_gl.zig](/src/nanovg_gl.zig) for OpenGL 2.0 and WebGL. WebGL is automatically chosen when targeting WebAssembly. There's an interface called `Params` defined in [internal.zig](src/internal.zig), which can be implemented by additional backends.

*NOTE:* The render target you're rendering to must have a stencil buffer.

## Drawing shapes with NanoVG

Drawing a simple shape using NanoVG consists of four steps:
1) begin a new shape,
2) define the path to draw, 
3) set fill or stroke,
4) and finally fill or stroke the path.

```zig
vg.beginPath();
vg.rect(100,100, 120,30);
vg.fillColor(nvg.rgba(255,192,0,255));
vg.fill();
```

Calling `beginPath()` will clear any existing paths and start drawing from a blank slate. There are a number of functions to define the path to draw, such as rectangle, rounded rectangle and ellipse, or you can use the common moveTo, lineTo, bezierTo and arcTo API to compose a path step-by-step.

## Understanding Composite Paths

Because of the way the rendering backend is built in NanoVG, drawing a composite path - that is a path consisting of multiple paths defining holes and fills - is a bit more involved. NanoVG uses the even-odd filling rule and by default the paths are wound in counterclockwise order. Keep that in mind when drawing using the low-level drawing API. In order to wind one of the predefined shapes as a hole, you should call `pathWinding(nvg.Winding.solidity(.hole))`, or `pathWinding(.cw)` **_after_** defining the path.

```zig
vg.beginPath();
vg.rect(100,100, 120,30);
vg.circle(120,120, 5);
vg.pathWinding(.cw); // Mark circle as a hole.
vg.fillColor(nvg.rgba(255,192,0,255));
vg.fill();
```

## API Reference

See [nanovg.zig](/src/nanovg.zig) for an API reference.

## Projects using nanovg-zig

- [MiniPixel by fabioarnold](https://github.com/fabioarnold/minipixel)
- [Snake by fabioarnold](https://fabioarnold.itch.io/snake)

## License
The original library and this rewrite are licensed under the [zlib license](LICENSE.txt)

Fonts used in the examples:
- Roboto licensed under [Apache license](http://www.apache.org/licenses/LICENSE-2.0)
- Entypo licensed under CC BY-SA 4.0.
- Noto Emoji licensed under [SIL Open Font License, Version 1.1](http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=OFL)

## Links
Uses [stb_truetype](http://nothings.org) for font rendering. Uses [stb_image](http://nothings.org) for image loading.
