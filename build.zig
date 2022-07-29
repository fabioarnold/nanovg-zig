const std = @import("std");

fn getRootDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

const root_dir = getRootDir();

pub fn addNanoVGPackage(artifact: *std.build.LibExeObjStep) void {
    artifact.addPackagePath("nanovg", root_dir ++ "/src/nanovg.zig");
    artifact.addIncludePath(root_dir ++ "/src");
    artifact.addCSourceFile(root_dir ++ "/src/fontstash.c", &.{ "-DFONS_NO_STDIO", "-fno-stack-protector" });
    artifact.addCSourceFile(root_dir ++ "/src/stb_image.c", &.{ "-DSTBI_NO_STDIO", "-fno-stack-protector" });
    artifact.linkLibC();
}

pub fn build(b: *std.build.Builder) !void {
    var artifact: *std.build.LibExeObjStep = undefined;
    const target = b.standardTargetOptions(.{});
    if (target.cpu_arch != null and (target.cpu_arch.? == .wasm32 or target.cpu_arch.? == .wasm64)) {
        artifact = b.addSharedLibrary("main", "examples/example_wasm.zig", .unversioned);
    } else {
        artifact = b.addExecutable("main", "examples/example_glfw.zig");
    }
    artifact.setTarget(target);
    artifact.setBuildMode(b.standardReleaseOptions());
    if (target.cpu_arch == null or (target.cpu_arch.? != .wasm32 and target.cpu_arch.? != .wasm64)) {
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
    addNanoVGPackage(artifact);
    artifact.install();
}
