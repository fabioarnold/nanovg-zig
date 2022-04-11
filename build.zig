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

pub fn build(b: *std.build.Builder) void {
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
        exe.linkSystemLibrary("glfw3");
        exe.linkSystemLibrary("GL");
        addNanoVGPackage(exe);
        exe.install();
    }
}
