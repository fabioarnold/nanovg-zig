const std = @import("std");

fn getRootDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

const root_dir = getRootDir();

pub fn addCSourceFiles(artifact: *std.build.CompileStep) void {
    artifact.addIncludePath(root_dir ++ "/src");
    artifact.addCSourceFile(root_dir ++ "/src/fontstash.c", &.{ "-DFONS_NO_STDIO", "-fno-stack-protector" });
    artifact.addCSourceFile(root_dir ++ "/src/stb_image.c", &.{ "-DSTBI_NO_STDIO", "-fno-stack-protector" });
    artifact.linkLibC();
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const target_wasm = if (target.cpu_arch) |arch| arch == .wasm32 or arch == .wasm64 else false;
    const artifact = init: {
        if (target_wasm) {
            break :init b.addSharedLibrary(.{
                .name = "main",
                .root_source_file = .{ .path = "examples/example_wasm.zig" },
                .target = target,
                .optimize = optimize,
            });
        } else {
            break :init b.addExecutable(.{
                .name = "main",
                .root_source_file = .{ .path = "examples/example_glfw.zig" },
                .target = target,
                .optimize = optimize,
            });
        }
    };

    const module = b.createModule(.{ .source_file = .{ .path = root_dir ++ "/src/nanovg.zig" } });
    artifact.addModule("nanovg", module);
    addCSourceFiles(artifact);

    if (!target_wasm) {
        artifact.addIncludePath("lib/gl2/include");
        artifact.addCSourceFile("lib/gl2/src/glad.c", &.{});
        if (target.isWindows()) {
            artifact.addVcpkgPaths(.dynamic) catch @panic("vcpkg not installed");
            if (artifact.vcpkg_bin_path) |bin_path| {
                for (&[_][]const u8{"glfw3.dll"}) |dll| {
                    const src_dll = try std.fs.path.join(b.allocator, &.{ bin_path, dll });
                    b.installBinFile(src_dll, dll);
                }
            }
            artifact.linkSystemLibrary("glfw3dll");
            artifact.linkSystemLibrary("opengl32");
        } else if (target.isDarwin()) {
            artifact.linkSystemLibrary("glfw3");
            artifact.linkFramework("OpenGL");
        } else {
            artifact.linkSystemLibrary("glfw3");
            artifact.linkSystemLibrary("GL");
        }
    }
    artifact.addIncludePath("examples");
    artifact.addCSourceFile("examples/stb_image_write.c", &.{ "-DSTBI_NO_STDIO", "-fno-stack-protector" });
    artifact.install();
}
