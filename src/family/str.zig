const std = @import("std");

const builtin = @import("builtin");
const target_endian = builtin.target.cpu.arch.endian();

const utils = @import("../utils.zig");
const asBigEndianBytes = utils.asBigEndianBytes;

const PackError = @import("../error.zig").PackError;

pub fn packStr(writer: anytype, input: []const u8) PackError(@TypeOf(writer))!void {
    const maxInt = std.math.maxInt;

    switch (input.len) {
        0...31 => {
            try writer.writeAll(&[_]u8{0b1010_0000 | @as(u8, @intCast(input.len))});
        },
        32...maxInt(u8) => |len| {
            try writer.writeAll(&[_]u8{ 0xD9, @as(u8, @intCast(len)) });
        },
        maxInt(u8) + 1...maxInt(u16) => |len| {
            try writer.writeAll(& //
                [_]u8{0xDA} //marker
                ++ asBigEndianBytes(target_endian, @as(u16, @intCast(len))) // value
            );
        },
        maxInt(u16) + 1...maxInt(u32) => |len| {
            try writer.writeAll(& //
                [_]u8{0xDB} //marker
                ++ asBigEndianBytes(target_endian, @as(u32, @intCast(len))) // value
            );
        },
        else => return error.ValueInvalid,
    }
    try writer.writeAll(input);
}
