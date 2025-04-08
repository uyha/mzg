const builtin = @import("builtin");
const std = @import("std");
const utils = @import("../utils.zig");

const PackError = @import("../error.zig").PackError;

pub fn packStr(input: []const u8, writer: anytype) PackError(@TypeOf(writer))!void {
    const maxInt = std.math.maxInt;

    if (input.len > maxInt(u32)) {
        return error.ValueInvalid;
    }

    switch (@as(u32, @intCast(input.len))) {
        0...31 => {
            try writer.writeAll(&[_]u8{0b1010_0000 | @as(u8, @intCast(input.len))});
        },
        32...maxInt(u8) => |len| {
            try writer.writeAll(&[_]u8{ 0xD9, @as(u8, @intCast(len)) });
        },
        maxInt(u8) + 1...maxInt(u16) => |len| {
            try writer.writeAll(&utils.header(u16, 0xDA, @intCast(len)));
        },
        maxInt(u16) + 1...maxInt(u32) => |len| {
            try writer.writeAll(&utils.header(u32, 0xDB, @intCast(len)));
        },
    }
    try writer.writeAll(input);
}

const parseFormat = @import("format.zig").parse;
const UnpackError = @import("../error.zig").UnpackError;
pub fn unpackStr(buffer: []const u8, out: *[]const u8) UnpackError!usize {
    var len: u32 = undefined;
    var size: usize = try unpackStrLen(buffer, &len);
    size += len;

    if (buffer.len < size) {
        return UnpackError.BufferUnderRun;
    }

    out.* = buffer[size - len .. size];

    return size;
}

pub fn unpackStrLen(buffer: []const u8, out: *u32) UnpackError!usize {
    const readInt = std.mem.readInt;

    const format = try parseFormat(buffer);
    switch (format) {
        .str => |str| switch (str) {
            .fix => {
                out.* = buffer[0] & 0b000_11111;
                return 1;
            },
            .str8 => {
                if (buffer.len < 2) {
                    return UnpackError.BufferUnderRun;
                }
                out.* = readInt(u8, buffer[1..2], std.builtin.Endian.big);
                return 2;
            },
            .str16 => {
                if (buffer.len < 3) {
                    return UnpackError.BufferUnderRun;
                }
                out.* = readInt(u16, buffer[1..3], std.builtin.Endian.big);
                return 3;
            },
            .str32 => {
                if (buffer.len < 5) {
                    return UnpackError.BufferUnderRun;
                }
                out.* = readInt(u32, buffer[1..5], std.builtin.Endian.big);
                return 5;
            },
        },
        else => return UnpackError.TypeIncompatible,
    }
}
