const builtin = @import("builtin");
const std = @import("std");

pub fn NativeUsize() type {
    return switch (@sizeOf(usize)) {
        @sizeOf(u32) => u32,
        @sizeOf(u64) => u64,
        else => @compileError(
            "usize is only support if it is the same size with either u32 or u64",
        ),
    };
}

pub fn header(
    comptime Value: type,
    marker: u8,
    value: Value,
) [1 + @sizeOf(Value)]u8 {
    var content = [1]u8{marker} ++ [1]u8{0} ** @sizeOf(Value);
    std.mem.writeInt(Value, content[1..], value, .big);
    return content;
}
