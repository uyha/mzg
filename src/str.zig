const std = @import("std");

const builtin = @import("builtin");
const target_endian = builtin.target.cpu.arch.endian();

const utils = @import("utils.zig");
const asBigEndianBytes = utils.asBigEndianBytes;

pub fn PackError(WriterError: type) type {
    return WriterError || error{StringTooLong};
}
pub fn packStr(writer: anytype, input: []const u8) PackError(@TypeOf(writer).Error)!void {
    switch (input.len) {
        0...31 => {
            try writer.writeAll(&[_]u8{0b1010_0000 | @as(u8, @intCast(input.len))});
        },
        32...std.math.maxInt(u8) => |len| {
            try writer.writeAll(&[_]u8{ 0xD9, @as(u8, @intCast(len)) });
        },
        std.math.maxInt(u8) + 1...std.math.maxInt(u16) => |len| {
            try writer.writeAll(& //
                [_]u8{0xDA} //marker
                ++ asBigEndianBytes(target_endian, @as(u16, @intCast(len))) // value
            );
        },
        std.math.maxInt(u16) + 1...std.math.maxInt(u32) => |len| {
            try writer.writeAll(& //
                [_]u8{0xDB} //marker
                ++ asBigEndianBytes(target_endian, @as(u32, @intCast(len))) // value
            );
        },
        else => return error.StringTooLong,
    }
    try writer.writeAll(input);
}
