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
    lib.addIncludePath("src");
    lib.addCSourceFile("src/fontstash.c", &.{ "-DFONS_NO_STDIO", "-fno-stack-protector" });
    lib.addCSourceFile("src/stb_image.c", &.{ "-DSTBI_NO_STDIO", "-fno-stack-protector" });
    lib.linkLibC();

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
    b.installArtifact(lib);

    if (target_wasm) {
        demo.rdynamic = true;
    } else {
        demo.addIncludePath("lib/gl2/include");
        demo.addCSourceFile("lib/gl2/src/glad.c", &.{});
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
    demo.addIncludePath("src");
    demo.addIncludePath("examples");
    demo.addCSourceFile("examples/stb_image_write.c", &.{ "-DSTBI_NO_STDIO", "-fno-stack-protector" });
    b.installArtifact(demo);

    const run_cmd = b.addRunArtifact(demo);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the demo");
    run_step.dependOn(&run_cmd.step);
}
