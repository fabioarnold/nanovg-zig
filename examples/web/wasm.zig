const std = @import("std");

pub extern fn performanceNow() f32;

pub extern fn download(filenamePtr: [*]const u8, filenameLen: usize, mimetypePtr: [*]const u8, mimetypeLen: usize, dataPtr: [*]const u8, dataLen: usize) void;

// Since we're using C libraries we have to use a global allocator.
pub var global_allocator: std.mem.Allocator = undefined;

export fn malloc(size: usize) callconv(.C) ?*anyopaque {
    const new_size = @sizeOf(usize) + size;
    const allocation = global_allocator.alloc(u8, new_size) catch return null;
    const bytes = allocation[0..@sizeOf(usize)];
    std.mem.writeIntSliceNative(usize, bytes, new_size);
    return @ptrCast(?*anyopaque, allocation[@sizeOf(usize)..].ptr);
}

fn getMallocSlice(ptr: *anyopaque) []u8 {
    const new_p = @intToPtr([*]u8, @ptrToInt(ptr) - @sizeOf(usize));
    const bytes = new_p[0..@sizeOf(usize)];
    const size = std.mem.readIntSliceNative(usize, bytes);
    return new_p[0..size];
}

export fn realloc(ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque {
    const p = ptr orelse return malloc(size);
    defer free(p);
    if (size == 0) return null;
    const slice = getMallocSlice(p)[@sizeOf(usize)..];
    const new = malloc(size);
    return memmove(new, slice.ptr, slice.len);
}

export fn free(ptr: ?*anyopaque) callconv(.C) void {
    const p = ptr orelse return;
    global_allocator.free(getMallocSlice(p));
}

export fn memmove(dest: ?*anyopaque, src: ?*anyopaque, n: usize) ?*anyopaque {
    const csrc = @ptrCast([*]u8, src)[0..n];
    const cdest = @ptrCast([*]u8, dest)[0..n];

    // Create a temporary array to hold data of src
    var buf: [1 << 12]u8 = undefined;
    const temp = if (n <= buf.len) buf[0..n] else @ptrCast([*]u8, malloc(n))[0..n];
    defer if (n > buf.len) free(@ptrCast(*anyopaque, temp));

    for (csrc) |c, i|
        temp[i] = c;

    for (temp) |c, i|
        cdest[i] = c;

    return dest;
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
