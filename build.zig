const std = @import("std");

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
    lib.addCSourceFile(.{ .file = .{ .path = "lib/gl2/src/glad.c" }, .flags = &.{} });
    lib.addIncludePath(.{ .path = "lib/gl2/include" });
    b.installArtifact(lib);

    const target_wasm = if (target.cpu_arch) |arch| arch.isWasm() else false;
    const demo = init: {
        if (target_wasm) {
            break :init b.addSharedLibrary(.{
                .name = "demo",
                .root_source_file = .{ .path = "examples/example_wasm.zig" },
                .target = target,
                .optimize = optimize,
            });
        } else {
            break :init b.addExecutable(.{
                .name = "demo",
                .root_source_file = .{ .path = "examples/example_glfw.zig" },
                .target = target,
                .optimize = optimize,
            });
        }
    };
    demo.addModule("nanovg", nanovg);
    demo.linkLibrary(lib);

    if (target_wasm) {
        demo.rdynamic = true;
    } else {
        demo.addIncludePath(.{ .path = "lib/gl2/include" });
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
            demo.linkSystemLibrary("glfw3");
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
    lib.addIncludePath(.{ .path = "src" });
    demo.addIncludePath(.{ .path = "examples" });
    demo.addCSourceFile(.{ .file = .{ .path = "examples/stb_image_write.c" }, .flags = &.{ "-DSTBI_NO_STDIO", "-fno-stack-protector" } });
    b.installArtifact(demo);

    const run_cmd = b.addRunArtifact(demo);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the demo");
    run_step.dependOn(&run_cmd.step);
}
