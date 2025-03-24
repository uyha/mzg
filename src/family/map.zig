const std = @import("std");
const maxInt = std.math.maxInt;

const builtin = @import("builtin");

const utils = @import("../utils.zig");
const asBigEndianBytes = utils.asBigEndianBytes;

const PackError = @import("../error.zig").PackError;

pub fn packMap(writer: anytype, size: usize) PackError(@TypeOf(writer))!void {
    const target_endian = comptime builtin.target.cpu.arch.endian();

    switch (size) {
        0...15 => try writer.writeAll(&[_]u8{0b1000_0000 | @as(u8, @intCast(size))}),
        16...maxInt(u16) => {
            try writer.writeAll(& //
                [_]u8{0xDE} //marker
                ++ asBigEndianBytes(target_endian, @as(u16, @intCast(size))) // value
            );
        },
        maxInt(u16) + 1...maxInt(u32) => {
            try writer.writeAll(& //
                [_]u8{0xDF} //marker
                ++ asBigEndianBytes(target_endian, @as(u32, @intCast(size))) // value
            );
        },
        else => return error.ValueTooBig,
    }
}
