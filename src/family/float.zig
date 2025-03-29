const builtin = @import("builtin");
const std = @import("std");
const utils = @import("../utils.zig");

pub fn packFloat(value: anytype, writer: anytype) @TypeOf(writer).Error!void {
    const Input = @TypeOf(value);

    comptime switch (@typeInfo(Input)) {
        .comptime_float => {
            // TODO: Not really sure how to check comptime_float if it fits f64, find a
            // way to check it later
        },
        .float => |float| {
            if (float.bits > 64) {
                @compileError(std.fmt.comptimePrint(
                    "cannot pack input with more than 64 bits as a float, input has {} bits",
                    .{float.bits},
                ));
            }
        },
        else => @compileError(@typeName(Input) ++ " cannot be packed as a float"),
    };

    switch (comptime Input) {
        f16, f32 => {
            try writer.writeAll(&utils.header(u32, 0xCA, @bitCast(@as(f32, value))));
        },
        comptime_float, f64 => {
            try writer.writeAll(&utils.header(u64, 0xCB, @bitCast(@as(f64, value))));
        },
        else => unreachable,
    }
}

const parseFormat = @import("format.zig").parse;
const UnpackError = @import("../error.zig").UnpackError;
pub fn unpackFloatWithEndian(
    comptime endian: std.builtin.Endian,
    buffer: []const u8,
    out: anytype,
) UnpackError!usize {
    const info = @typeInfo(@TypeOf(out));
    if (comptime info != .pointer or info.pointer.size != .one or info.pointer.is_const) {
        @compileError("`out` has to be a mutable singe-item pointer");
    }
    switch (@typeInfo(info.pointer.child)) {
        .float => |float| {
            switch (float.bits) {
                32, 64 => {},
                else => @compileError(std.fmt.comptimePrint(
                    "Cannot unpack to a float with {} bits, only f32 and f64 are allowed",
                    .{float.bits},
                )),
            }
        },
        else => return UnpackError.TypeIncompatible,
    }

    const format = try parseFormat(buffer);

    if (format != .float) {
        return UnpackError.TypeIncompatible;
    }

    const size: usize = switch (format.float) {
        .f32 => 5,
        .f64 => 9,
    };

    if (buffer.len < size) {
        return UnpackError.BufferUnderRun;
    }
    if (@sizeOf(info.pointer.child) < size - 1) {
        return UnpackError.ValueInvalid;
    }

    const parse = struct {
        fn parse(comptime Raw: type, content: []const u8) UnpackError!Raw {
            var raw: Raw = undefined;
            @memcpy(std.mem.asBytes(&raw), content);
            if (comptime endian == .little) {
                std.mem.reverse(u8, std.mem.asBytes(&raw));
            }
            return raw;
        }
    }.parse;

    out.* = switch (format.float) {
        .f32 => @floatCast(try parse(f32, buffer[1..size])),
        .f64 => @floatCast(try parse(f64, buffer[1..size])),
    };

    return size;
}

pub fn unpackFloat(buffer: []const u8, out: anytype) UnpackError!usize {
    return unpackFloatWithEndian(comptime builtin.target.cpu.arch.endian(), buffer, out);
}
