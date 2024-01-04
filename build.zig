const std = @import("std");

fn installDemo(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.OptimizeMode, name: []const u8, root_source_file: []const u8, nanovg: *std.build.Module, lib: *std.build.Step.Compile) !void {
    const target_wasm = if (target.cpu_arch) |arch| arch.isWasm() else false;
    const demo = b.addExecutable(.{
        .name = name,
        .root_source_file = .{ .path = root_source_file },
        .main_mod_path = .{ .path = "." },
        .target = target,
        .optimize = optimize,
    });
    demo.addModule("nanovg", nanovg);
    demo.linkLibrary(lib);

    if (target_wasm) {
        demo.rdynamic = true;
        demo.entry = .disabled;
    } else {
        demo.addIncludePath(.{ .path = "lib/gl2/include" });
        demo.addCSourceFile(.{ .file = .{ .path = "lib/gl2/src/glad.c" }, .flags = &.{} });
        if (target.isWindows()) {
            demo.addVcpkgPaths(.dynamic) catch @panic("vcpkg not installed");
            if (demo.vcpkg_bin_path) |bin_path| {
                for (&[_][]const u8{"glfw3.dll"}) |dll| {
                    const src_dll = try std.fs.path.join(b.allocator, &.{ bin_path, dll });
                    b.installBinFile(src_dll, dll);
                }
            }
            demo.linkSystemLibrary("glfw3dll");
            demo.linkSystemLibrary("opengl32");
        } else if (target.isDarwin()) {
            demo.addIncludePath(.{ .path = "/opt/homebrew/include" });
            demo.addLibraryPath(.{ .path = "/opt/homebrew/lib" });
            demo.linkSystemLibrary("glfw");
            demo.linkFramework("OpenGL");
        } else if (target.isLinux()) {
            demo.linkSystemLibrary("glfw3");
            demo.linkSystemLibrary("GL");
            demo.linkSystemLibrary("X11");
        } else {
            std.log.warn("Unsupported target: {}", .{target});
            demo.linkSystemLibrary("glfw3");
            demo.linkSystemLibrary("GL");
        }
    }
    demo.addIncludePath(.{ .path = "examples" });
    demo.addCSourceFile(.{ .file = .{ .path = "examples/stb_image_write.c" }, .flags = &.{ "-DSTBI_NO_STDIO", "-fno-stack-protector" } });
    b.installArtifact(demo);
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const nanovg = b.addModule("nanovg", .{ .source_file = .{ .path = "src/nanovg.zig" } });

    const lib = b.addStaticLibrary(.{
        .name = "nanovg",
        .root_source_file = .{ .path = "src/nanovg.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib.addModule("nanovg", nanovg);
    lib.addIncludePath(.{ .path = "src" });
    lib.addCSourceFile(.{ .file = .{ .path = "src/fontstash.c" }, .flags = &.{ "-DFONS_NO_STDIO", "-fno-stack-protector" } });
    lib.addCSourceFile(.{ .file = .{ .path = "src/stb_image.c" }, .flags = &.{ "-DSTBI_NO_STDIO", "-fno-stack-protector" } });
    lib.linkLibC();
    lib.installHeader("src/fontstash.h", "fontstash.h");
    lib.installHeader("src/stb_image.h", "stb_image.h");
    lib.installHeader("src/stb_truetype.h", "stb_truetype.h");
    b.installArtifact(lib);

    const target_wasm = if (target.cpu_arch) |arch| arch.isWasm() else false;
    const root_source_file = if (target_wasm) "examples/example_wasm.zig" else "examples/example_glfw.zig";
    const demo = b.addExecutable(.{
        .name = "demo",
        .root_source_file = .{ .path = root_source_file },
        .main_mod_path = .{ .path = "." },
        .target = target,
        .optimize = optimize,
    });
    demo.addModule("nanovg", nanovg);
    demo.linkLibrary(lib);

    if (target_wasm) {
        try installDemo(b, target, optimize, "demo", "examples/example_wasm.zig", nanovg, lib);
    } else {
        try installDemo(b, target, optimize, "demo_glfw", "examples/example_glfw.zig", nanovg, lib);
        try installDemo(b, target, optimize, "demo_fbo", "examples/example_fbo.zig", nanovg, lib);
        try installDemo(b, target, optimize, "demo_clip", "examples/example_clip.zig", nanovg, lib);
    }
}
