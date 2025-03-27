const builtin = @import("builtin");
const std = @import("std");
const utils = @import("utils.zig");

const PackError = @import("error.zig").PackError;
pub fn packArray(size: usize, writer: anytype) PackError(@TypeOf(writer))!void {
    const maxInt = std.math.maxInt;

    switch (size) {
        0...15 => try writer.writeAll(&[_]u8{0b1001_0000 | @as(u8, @intCast(size))}),
        16...maxInt(u16) => {
            return writer.writeAll(&utils.header(u16, 0xDC, @intCast(size)));
        },
        maxInt(u16) + 1...maxInt(u32) => {
            return writer.writeAll(&utils.header(u32, 0xDD, @intCast(size)));
        },
        else => return error.ValueInvalid,
    }
}

const parseFormat = @import("format.zig").parse;
const UnpackError = @import("error.zig").UnpackError;
pub fn unpackArray(buffer: []const u8, out: anytype) UnpackError!usize {
    const info = @typeInfo(@TypeOf(out));
    if (comptime info != .pointer or info.pointer.size != .one or info.pointer.is_const) {
        @compileError("`out` has to be a pointer to an int");
    }

    const Child = info.pointer.child;

    switch (@typeInfo(Child)) {
        .int => {},
        else => @compileError("`out` has to be a pointer to an int"),
    }

    switch (try parseFormat(buffer)) {
        .array => |array| switch (array) {
            .fix => {
                out.* = utils.readIntBounded(
                    Child,
                    u8,
                    &[_]u8{buffer[0] & 0x0F},
                ) orelse return UnpackError.ValueInvalid;
                return 1;
            },
            .arr16 => {
                if (buffer.len < 3) {
                    return UnpackError.BufferUnderRun;
                }
                out.* = utils.readIntBounded(
                    Child,
                    u16,
                    buffer[1..3],
                ) orelse return UnpackError.ValueInvalid;
                return 3;
            },
            .arr32 => {
                if (buffer.len < 5) {
                    return UnpackError.BufferUnderRun;
                }
                out.* = utils.readIntBounded(
                    Child,
                    u32,
                    buffer[1..5],
                ) orelse return UnpackError.ValueInvalid;
                return 5;
            },
        },
        else => return UnpackError.TypeIncompatible,
    }
}
