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

const parseFormat = @import("../unpack.zig").parseFormat;
const UnpackError = @import("../error.zig").UnpackError;
pub const Int = enum { pos, neg, u8, u16, u32, u64, i8, i16, i32, i64 };
pub fn unpackIntWithEndian(
    comptime endian: std.builtin.Endian,
    buffer: []const u8,
    out: anytype,
) UnpackError!usize {
    const maxInt = std.math.maxInt;
    const minInt = std.math.minInt;

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

    const parse = struct {
        fn parse(comptime Raw: type, content: []const u8) UnpackError!Raw {
            var raw: Raw = undefined;
            @memcpy(std.mem.asBytes(&raw), content);
            if (comptime endian == .little) {
                std.mem.reverse(u8, std.mem.asBytes(&raw));
            }
            if (raw < minInt(Child) or maxInt(Child) < raw) {
                return UnpackError.ValueInvalid;
            }
            return raw;
        }
    }.parse;

    out.* = switch (format.int) {
        .pos => @intCast(try parse(u8, buffer[0..size])),
        .neg => @intCast(try parse(i8, buffer[0..size])),
        .u8 => @intCast(try parse(u8, buffer[1..size])),
        .u16 => @intCast(try parse(u16, buffer[1..size])),
        .u32 => @intCast(try parse(u32, buffer[1..size])),
        .u64 => @intCast(try parse(u64, buffer[1..size])),
        .i8 => @intCast(try parse(i8, buffer[1..size])),
        .i16 => @intCast(try parse(i16, buffer[1..size])),
        .i32 => @intCast(try parse(i32, buffer[1..size])),
        .i64 => @intCast(try parse(i64, buffer[1..size])),
    };

    return size;
}

pub fn unpackInt(buffer: []const u8, out: anytype) UnpackError!usize {
    return unpackIntWithEndian(comptime builtin.target.cpu.arch.endian(), buffer, out);
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
