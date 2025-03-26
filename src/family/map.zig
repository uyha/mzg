const builtin = @import("builtin");
const std = @import("std");
const utils = @import("../utils.zig");

const PackError = @import("../error.zig").PackError;

pub fn packMap(writer: anytype, size: usize) PackError(@TypeOf(writer))!void {
    const maxInt = std.math.maxInt;

    switch (size) {
        0...15 => try writer.writeAll(&[_]u8{0b1000_0000 | @as(u8, @intCast(size))}),
        16...maxInt(u16) => {
            try writer.writeAll(&utils.header(u16, 0xDE, @intCast(size)));
        },
        maxInt(u16) + 1...maxInt(u32) => {
            try writer.writeAll(&utils.header(u32, 0xDF, @intCast(size)));
        },
        else => return error.ValueInvalid,
    }
}
