const std = @import("std");
const maxInt = std.math.maxInt;

const builtin = @import("builtin");

const utils = @import("utils.zig");
const asBigEndianBytes = utils.asBigEndianBytes;

pub fn PackError(WriterError: type) type {
    return WriterError || error{ArrayTooLong};
}
pub fn packArray(writer: anytype, size: usize) PackError(@TypeOf(writer).Error)!void {
    const target_endian = comptime builtin.target.cpu.arch.endian();

    switch (size) {
        0...15 => |len| try writer.writeByte(0b1001_0000 | @as(u8, @intCast(len))),
        16...maxInt(u16) => {
            try writer.writeAll(& //
                [_]u8{0xDC} // marker
                ++ asBigEndianBytes(target_endian, @as(u16, @intCast(size))) // size
            );
        },
        maxInt(u16) + 1...maxInt(u32) => {
            try writer.writeAll(& //
                [_]u8{0xDD} // marker
                ++ asBigEndianBytes(target_endian, @as(u32, @intCast(size))) // size
            );
        },
        else => return error.ArrayTooLong,
    }
}

test "packArray" {
    const expect = @import("utils.zig").expect;

    try expect(packArray, 0, &[_]u8{0x90});
    try expect(packArray, 15, &[_]u8{0x9F});
    try expect(packArray, 16, &[_]u8{ 0xDC, 0x00, 0x10 });
    try expect(packArray, maxInt(u16), &[_]u8{ 0xDC, 0xFF, 0xFF });
    try expect(packArray, maxInt(u16) + 1, &[_]u8{ 0xDD, 0x00, 0x01, 0x00, 0x00 });
    try expect(packArray, maxInt(u32), &[_]u8{ 0xDD, 0xFF, 0xFF, 0xFF, 0xFF });
    try expect(packArray, maxInt(u32) + 1, error.ArrayTooLong);
}
