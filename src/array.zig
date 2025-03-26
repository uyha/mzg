const builtin = @import("builtin");
const std = @import("std");
const utils = @import("utils.zig");

const PackError = @import("error.zig").PackError;
pub fn packArray(writer: anytype, size: usize) PackError(@TypeOf(writer))!void {
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
