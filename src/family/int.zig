// Originally, there was a `behavior` parameter that contains a `priority` field that
// specifies if the packing procedure should prioritize for the smallest amount of byte
// written, or skipping the value checks and just write the bytes according to the type
// of input. This was done with the assumption that skipping the checks can have some
// performance gain. However, with some basic benchmarking, skipping the checks hinders
// the performance when the act of writing the bytes is more costly than the checks
// (almost always is). Even when the cost of the writing is 0 (a null writer), no
// statistically significance is found between the `.size` and `.speed` priority. Hence,
// the optimization for size is chosen to always be the behavior.
pub fn packInt(value: anytype, writer: *Writer) Writer.Error!void {
    const maxInt = std.math.maxInt;
    const minInt = std.math.minInt;
    const Input = @TypeOf(value);

    comptime switch (@typeInfo(Input)) {
        .comptime_int => if (value < minInt(i64) or value > maxInt(u64)) {
            @compileError(std.fmt.comptimePrint(
                "cannot pack input outside of [-2^63, 2^64 -1], input is {}",
                .{value},
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

    if (-32 <= value and value <= maxInt(u7)) {
        return try writer.writeAll(&[_]u8{@bitCast(@as(i8, @intCast(value)))});
    }

    if (maxInt(u7) < value) {
        inline for (.{ u8, u16, u32, u64 }) |T| {
            if (value <= maxInt(T)) {
                return writer.writeAll(&utils.header(T, marker(T), @intCast(value)));
            }
        }
        unreachable;
    }

    inline for (.{ i8, i16, i32, i64 }) |T| {
        if (minInt(T) <= value) {
            return writer.writeAll(&utils.header(T, marker(T), @intCast(value)));
        }
    }
    unreachable;
}

pub fn unpackInt(buffer: []const u8, out: anytype) UnpackError!usize {
    const info = @typeInfo(@TypeOf(out));
    if (comptime info != .pointer or info.pointer.size != .one or info.pointer.is_const) {
        @compileError("`out` has to be a pointer to an int");
    }

    const Child = info.pointer.child;

    switch (@typeInfo(Child)) {
        .int => {},
        else => @compileError("`out` has to be a pointer to an int"),
    }

    const format = try parseFormat(buffer);

    if (format != .int) {
        return UnpackError.TypeIncompatible;
    }

    const size: usize = switch (format.int) {
        .pos, .neg => 1,
        .u8, .i8 => 2,
        .u16, .i16 => 3,
        .u32, .i32 => 5,
        .u64, .i64 => 9,
    };

    if (buffer.len < size) {
        return UnpackError.BufferUnderRun;
    }

    out.* = switch (format.int) {
        .pos => utils.readIntBounded(Child, u8, buffer[0..1]),
        .neg => utils.readIntBounded(Child, i8, buffer[0..1]),
        .u8 => utils.readIntBounded(Child, u8, buffer[1..2]),
        .i8 => utils.readIntBounded(Child, i8, buffer[1..2]),
        .u16 => utils.readIntBounded(Child, u16, buffer[1..3]),
        .i16 => utils.readIntBounded(Child, i16, buffer[1..3]),
        .u32 => utils.readIntBounded(Child, u32, buffer[1..5]),
        .i32 => utils.readIntBounded(Child, i32, buffer[1..5]),
        .u64 => utils.readIntBounded(Child, u64, buffer[1..9]),
        .i64 => utils.readIntBounded(Child, i64, buffer[1..9]),
    } orelse return UnpackError.ValueInvalid;

    return size;
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
        usize => marker(utils.NativeUsize()),
        else => @compileError(@typeName(T) ++ " cannot be pack as an int"),
    };
}

const builtin = @import("builtin");

const std = @import("std");
const Writer = std.io.Writer;

const utils = @import("../utils.zig");
const parseFormat = @import("format.zig").parse;
const PackError = @import("../error.zig").PackError;
const UnpackError = @import("../error.zig").UnpackError;
