const std = @import("std");
const builtin = @import("builtin");

const utils = @import("utils.zig");
const asBigEndianBytes = utils.asBigEndianBytes;

const PackError = @import("error.zig").PackError;

pub fn packBin(writer: anytype, input: []const u8) PackError(@TypeOf(writer))!void {
    const target_endian = comptime builtin.target.cpu.arch.endian();

    switch (input.len) {
        0...std.math.maxInt(u8) => |len| {
            try writer.writeAll(&[_]u8{ 0xC4, @as(u8, @intCast(len)) });
        },
        std.math.maxInt(u8) + 1...std.math.maxInt(u16) => |len| {
            try writer.writeAll(& //
                [_]u8{0xC5} // marker
                ++ asBigEndianBytes(target_endian, @as(u16, @intCast(len))) // size
            );
        },
        std.math.maxInt(u16) + 1...std.math.maxInt(u32) => |len| {
            try writer.writeAll(& //
                [_]u8{0xC6} // marker
                ++ asBigEndianBytes(target_endian, @as(u32, @intCast(len))) // size
            );
        },
        else => return error.ValueTooBig,
    }
    try writer.writeAll(input);
}
