const builtin = @import("builtin");
const std = @import("std");
const utils = @import("../utils.zig");

const PackError = @import("../error.zig").PackError;

pub fn packBin(writer: anytype, input: []const u8) PackError(@TypeOf(writer))!void {
    const maxInt = std.math.maxInt;

    switch (input.len) {
        0...maxInt(u8) => |len| {
            try writer.writeAll(&[_]u8{ 0xC4, @as(u8, @intCast(len)) });
        },
        maxInt(u8) + 1...maxInt(u16) => |len| {
            try writer.writeAll(&utils.header(u16, 0xC5, @intCast(len)));
        },
        maxInt(u16) + 1...maxInt(u32) => |len| {
            try writer.writeAll(&utils.header(u32, 0xC6, @intCast(len)));
        },
        else => return error.ValueInvalid,
    }
    try writer.writeAll(input);
}

pub const Bin = enum { bin8, bin16, bin32 };
const parseFormat = @import("../unpack.zig").parseFormat;
const UnpackError = @import("../error.zig").UnpackError;
pub fn unpackBin(buffer: []const u8, out: *[]const u8) UnpackError!usize {
    const readInt = std.mem.readInt;

    const format = try parseFormat(buffer);
    var size: usize = undefined;
    var len: usize = undefined;

    switch (format) {
        .bin => |str| switch (str) {
            .bin8 => {
                if (buffer.len < 2) {
                    return UnpackError.BufferUnderRun;
                }
                len = readInt(u8, buffer[1..2], std.builtin.Endian.big);
                size = len + 2;
            },
            .bin16 => {
                if (buffer.len < 3) {
                    return UnpackError.BufferUnderRun;
                }
                len = readInt(u16, buffer[1..3], std.builtin.Endian.big);
                size = len + 3;
            },
            .bin32 => {
                if (buffer.len < 5) {
                    return UnpackError.BufferUnderRun;
                }
                len = readInt(u32, buffer[1..5], std.builtin.Endian.big);
                size = len + 5;
            },
        },
        else => return UnpackError.TypeIncompatible,
    }

    if (buffer.len < size) {
        return UnpackError.BufferUnderRun;
    }

    out.* = buffer[size - len .. size];

    return size;
}
