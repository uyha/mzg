const std = @import("std");
const builtin = @import("builtin");

const utils = @import("../utils.zig");
const asBigEndianBytes = utils.asBigEndianBytes;

const PackError = @import("../error.zig").PackError;

pub fn packBin(writer: anytype, input: []const u8) PackError(@TypeOf(writer))!void {
    const maxInt = std.math.maxInt;
    const target_endian = comptime builtin.target.cpu.arch.endian();

    switch (input.len) {
        0...maxInt(u8) => |len| {
            try writer.writeAll(&[_]u8{ 0xC4, @as(u8, @intCast(len)) });
        },
        maxInt(u8) + 1...maxInt(u16) => |len| {
            try writer.writeAll(& //
                [_]u8{0xC5} // marker
                ++ asBigEndianBytes(target_endian, @as(u16, @intCast(len))) // size
            );
        },
        maxInt(u16) + 1...maxInt(u32) => |len| {
            try writer.writeAll(& //
                [_]u8{0xC6} // marker
                ++ asBigEndianBytes(target_endian, @as(u32, @intCast(len))) // size
            );
        },
        else => return error.ValueTooBig,
    }
    try writer.writeAll(input);
}
