const std = @import("std");

fn getRootDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

pub fn addNanoVGPackage(target: *std.build.LibExeObjStep) void {
    target.addPackagePath("nanovg", getRootDir() ++ "/src/nanovg.zig");
    target.addIncludePath(getRootDir() ++ "/src");
    target.addCSourceFile(getRootDir() ++ "/src/fontstash.c", &.{"-DFONS_NO_STDIO", "-fno-stack-protector"});
    target.addCSourceFile(getRootDir() ++ "/src/stb_image.c", &.{"-DSTBI_NO_STDIO", "-fno-stack-protector"});
    target.linkLibC();
}

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    if (target.cpu_arch != null and target.cpu_arch.? == .wasm32) {
        const lib = b.addSharedLibrary("main", "examples/example_wasm.zig", .unversioned);
        lib.setTarget(target);
        lib.setBuildMode(mode);
        addNanoVGPackage(lib);
        lib.install();
    } else {
        const exe = b.addExecutable("main", "examples/example_glfw.zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.addIncludePath("lib/gl2/include");
        exe.addCSourceFile("lib/gl2/src/glad.c", &.{});
        if (exe.target.isWindows()) {
            exe.addVcpkgPaths(.dynamic) catch @panic("vcpkg not installed");
            if (exe.vcpkg_bin_path) |bin_path| {
                for (&[_][]const u8{ "glfw3.dll" }) |dll| {
                    const src_dll = try std.fs.path.join(b.allocator, &.{ bin_path, dll });
                    b.installBinFile(src_dll, dll);
                }
            }
            exe.linkSystemLibrary("glfw3dll");
            exe.linkSystemLibrary("opengl32");
        } else if (exe.target.isDarwin()) {
            exe.linkSystemLibrary("glfw3");
            exe.linkFramework("OpenGL");
        } else {
            exe.linkSystemLibrary("glfw3");
            exe.linkSystemLibrary("GL");
        }
        addNanoVGPackage(exe);
        exe.install();
    }
}
