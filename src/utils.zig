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

pub inline fn asBigEndianBytes(
    comptime endian: std.builtin.Endian,
    input: anytype,
) [@sizeOf(@TypeOf(input))]u8 {
    const Input = @TypeOf(input);
    const raw = raw: switch (Input) {
        f32, f64 => |Float| {
            const Target = if (Float == f32) u32 else u64;
            break :raw @as(Target, @bitCast(input));
        },
        u8, u16, u32, u64, i8, i16, i32, i64 => input,
        usize => @as(NativeUsize(), input),
        else => @compileError(std.fmt.comptimePrint(
            "{s} is not supported by this function",
            .{@typeName(Input)},
        )),
    };

    return std.mem.toBytes(if (endian == .little) @byteSwap(raw) else raw);
}
