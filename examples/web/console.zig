const std = @import("std");

var buf: [1000]u8 = undefined;

pub fn log(comptime fmt: []const u8, args: anytype) void {
    const str = std.fmt.bufPrint(&buf, fmt, args) catch unreachable;
    consoleLog(str.ptr, str.len);
}

extern fn consoleLog(ptr: [*]const u8, len: usize) void;