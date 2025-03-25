const std = @import("std");

const builtin = @import("builtin");

const utils = @import("../utils.zig");
const NativeUsize = utils.NativeUsize;
const asBigEndianBytes = utils.asBigEndianBytes;

const PackError = @import("../error.zig").PackError;

// Originally, there was a `behavior` parameter that contains a `priority` field that
// specifies if the packing procedure should prioritize for the smallest amount of byte
// written, or skipping the value checks and just write the bytes according to the type
// of input. This was done with the assumption that skipping the checks can have some
// performance gain. However, with some basic benchmarking, skipping the checks hinders
// the performance when the act of writing the bytes is more costly than the checks
// (almost always is). Even when the cost of the writing is 0 (a null writer), no
// statistically significance is found between the `.size` and `.speed` priority. Hence,
// the optimization for size is chosen to always be the behavior.
pub fn packIntWithEndian(
    comptime endian: std.builtin.Endian,
    writer: anytype,
    input: anytype,
) @TypeOf(writer).Error!void {
    const maxInt = std.math.maxInt;
    const minInt = std.math.minInt;
    const Input = @TypeOf(input);

    comptime switch (@typeInfo(Input)) {
        .comptime_int => if (input < minInt(i64) or input > maxInt(u64)) {
            @compileError(std.fmt.comptimePrint(
                "cannot pack input outside of [-2^63, 2^64 -1], input is {}",
                .{input},
            ));
        },
        .int => |int| if (int.bits > 64) {
            @compileError(std.fmt.comptimePrint(
                "cannot pack input with more than 64 bits as an int, input has {} bits",
                .{int.bits},
            ));
        },
        else => @compileError(@typeName(Input) ++ " cannot be packed as an int"),
    };

    if (-32 <= input and input <= maxInt(u7)) {
        return try writer.writeAll(&[_]u8{@bitCast(@as(i8, @intCast(input)))});
    }

    if (maxInt(u7) < input) {
        inline for (.{ u8, u16, u32, u64 }) |T| {
            if (input <= maxInt(T)) {
                try writer.writeAll(& //
                    [_]u8{marker(T)} //marker
                    ++ asBigEndianBytes(endian, @as(T, @intCast(input))) // value
                );
                return;
            }
        }
        unreachable;
    }

    inline for (.{ i8, i16, i32, i64 }) |T| {
        if (minInt(T) <= input) {
            try writer.writeAll(& //
                [_]u8{marker(T)} //marker
                ++ asBigEndianBytes(endian, @as(T, @intCast(input))) // value
            );
            return;
        }
    }
    unreachable;
}

pub fn packInt(
    writer: anytype,
    input: anytype,
) @TypeOf(writer).Error!void {
    return packIntWithEndian(
        comptime builtin.target.cpu.arch.endian(),
        writer,
        input,
    );
}

fn marker(comptime T: type) u8 {
    return switch (comptime T) {
        u8 => 0xCC,
        u16 => 0xCD,
        u32 => 0xCE,
        u64 => 0xCF,
        i8 => 0xD0,
        i16 => 0xD1,
        i32 => 0xD2,
        i64 => 0xD3,
        usize => marker(NativeUsize()),
        else => @compileError(@typeName(T) ++ " cannot be pack as an int"),
    };
}
