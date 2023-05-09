const std = @import("std");
const logger = std.log.scoped(.wasm);

pub extern fn performanceNow() f32;

pub extern fn download(filenamePtr: [*]const u8, filenameLen: usize, mimetypePtr: [*]const u8, mimetypeLen: usize, dataPtr: [*]const u8, dataLen: usize) void;

extern fn wasm_log_write(ptr: [*]const u8, len: usize) void;

extern fn wasm_log_flush() void;

const WriteError = error{};
const LogWriter = std.io.Writer(void, WriteError, writeLog);

fn writeLog(_: void, msg: []const u8) WriteError!usize {
    wasm_log_write(msg.ptr, msg.len);
    return msg.len;
}

/// Overwrite default log handler
pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = switch (message_level) {
        .err => "error",
        .warn => "warning",
        .info => "info",
        .debug => "debug",
    };
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";

    (LogWriter{ .context = {} }).print(level_txt ++ prefix2 ++ format ++ "\n", args) catch return;

    wasm_log_flush();
}

// Since we're using C libraries we have to use a global allocator.
pub var global_allocator: std.mem.Allocator = undefined;

const malloc_alignment = 16;

export fn malloc(size: usize) callconv(.C) ?*anyopaque {
    const buffer = global_allocator.alignedAlloc(u8, malloc_alignment, size + malloc_alignment) catch {
        logger.err("Allocation failure for size={}", .{size});
        return null;
    };
    std.mem.writeIntNative(usize, buffer[0..@sizeOf(usize)], buffer.len);
    return buffer.ptr + malloc_alignment;
}

export fn realloc(ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque {
    const p = ptr orelse return malloc(size);
    defer free(p);
    if (size == 0) return null;
    const actual_buffer = @ptrCast([*]u8, p) - malloc_alignment;
    const len = std.mem.readIntNative(usize, actual_buffer[0..@sizeOf(usize)]);
    const new = malloc(size);
    return memmove(new, actual_buffer + malloc_alignment, len);
}

export fn free(ptr: ?*anyopaque) callconv(.C) void {
    const actual_buffer = @ptrCast([*]u8, ptr orelse return) - 16;
    const len = std.mem.readIntNative(usize, actual_buffer[0..@sizeOf(usize)]);
    global_allocator.free(actual_buffer[0..len]);
}

export fn memmove(dest: ?*anyopaque, src: ?*anyopaque, n: usize) ?*anyopaque {
    const csrc = @ptrCast([*]u8, src)[0..n];
    const cdest = @ptrCast([*]u8, dest)[0..n];

    // Create a temporary array to hold data of src
    var buf: [1 << 12]u8 = undefined;
    const temp = if (n <= buf.len) buf[0..n] else @ptrCast([*]u8, malloc(n))[0..n];
    defer if (n > buf.len) free(@ptrCast(*anyopaque, temp));

    for (csrc, 0..) |c, i|
        temp[i] = c;

    for (temp, 0..) |c, i|
        cdest[i] = c;

    return dest;
}

export fn memcpy(dst: ?[*]u8, src: ?[*]const u8, num: usize) ?[*]u8 {
    if (dst == null or src == null)
        @panic("Invalid usage of memcpy!");
    std.mem.copy(u8, dst.?[0..num], src.?[0..num]);
    return dst;
}

export fn memset(ptr: ?[*]u8, value: c_int, num: usize) ?[*]u8 {
    if (ptr == null)
        @panic("Invalid usage of memset!");
    // FIXME: the optimizer replaces this with a memset call which leads to a stack overflow.
    // std.mem.set(u8, ptr.?[0..num], @intCast(u8, value));
    for (ptr.?[0..num]) |*d|
        d.* = @intCast(u8, value);
    return ptr;
}

export fn strlen(s: ?[*:0]const u8) usize {
    return std.mem.indexOfSentinel(u8, 0, s orelse return 0);
}

export fn strncpy(dest: [*]u8, src: [*]const u8, n: usize) ?[*]u8 {
    var i: usize = 0;
    while (i < n and src[i] != 0) : (i += 1) dest[i] = src[i];
    while (i < n) : (i += 1) dest[i] = 0;
    return dest;
}

export fn strcmp(s1: ?[*]u8, s2: ?[*]u8) c_int {
    var i: usize = 0;
    while (s1.?[i] != 0 and s2.?[i] != 0) : (i += 1) {
        if (s1.?[i] < s2.?[i]) return -1;
        if (s1.?[i] > s2.?[i]) return 1;
    }
    if (s1.?[i] == s2.?[i]) return 0;
    if (s1.?[i] == 0) return -1;
    return 1;
}

export fn strncmp(s1: ?[*]u8, s2: ?[*]u8, n: usize) c_int {
    var i: usize = 0;
    while (s1.?[i] != 0 and s2.?[i] != 0 and i < n) : (i += 1) {
        if (s1.?[i] < s2.?[i]) return -1;
        if (s1.?[i] > s2.?[i]) return 1;
    }
    if (s1.?[i] == s2.?[i]) return 0;
    if (s1.?[i] == 0) return -1;
    return 1;
}

export fn strtol(nptr: [*]const u8, endptr: *?[*]const u8, base: c_int) c_long {
    if (base != 10) unreachable; // not implemented
    var l: c_long = 0;
    var i: usize = 0;
    while (nptr[i] != 0) : (i += 1) {
        const c = nptr[i];
        if (c >= '0' and c <= '9') {
            l *= 10;
            l += c - '0';
        } else {
            break;
        }
    }
    endptr.* = @ptrCast([*]const u8, &nptr[i]);
    return l;
}

export fn __assert_fail(a: i32, b: i32, c: i32, d: i32) void {
    _ = a;
    _ = b;
    _ = c;
    _ = d;
}

export fn abs(i: c_int) c_int {
    return if (i < 0) -i else i;
}

export fn pow(x: f64, y: f64) f64 {
    return std.math.pow(f64, x, y);
}

export fn ldexp(x: f64, n: c_int) f64 {
    return std.math.ldexp(x, n);
}

export var __stack_chk_guard: c_ulong = undefined;

export fn __stack_chk_guard_setup() void {
    __stack_chk_guard = 0xBAAAAAAD;
}

export fn __stack_chk_fail() void {
    @panic("stack fail");
}
