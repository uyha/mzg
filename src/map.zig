const std = @import("std");
const maxInt = std.math.maxInt;

const builtin = @import("builtin");

const utils = @import("utils.zig");
const asBigEndianBytes = utils.asBigEndianBytes;

pub fn PackError(WriterError: type) type {
    return WriterError || error{MapTooLong};
}
pub fn packMap(writer: anytype, size: usize) PackError(@TypeOf(writer).Error)!void {
    const target_endian = comptime builtin.target.cpu.arch.endian();

    switch (size) {
        0...15 => |len| try writer.writeByte(0b1000_0000 | @as(u8, @intCast(len))),
        16...maxInt(u16) => |len| {
            try writer.writeAll(& //
                [_]u8{0xDE} //marker
                ++ asBigEndianBytes(target_endian, @as(u16, @intCast(len))) // value
            );
        },
        maxInt(u16) + 1...maxInt(u32) => |len| {
            try writer.writeAll(& //
                [_]u8{0xDF} //marker
                ++ asBigEndianBytes(target_endian, @as(u32, @intCast(len))) // value
            );
        },
        else => return error.MapTooLong,
    }
}
