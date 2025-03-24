const std = @import("std");
const maxInt = std.math.maxInt;

const builtin = @import("builtin");
const target_endian = builtin.target.cpu.arch.endian();

const utils = @import("utils.zig");
const NativeUsize = utils.NativeUsize;
const writeWithEndian = utils.writeWithEndian;

pub fn Error(WriterError: type) type {
    return WriterError || error{MapTooLong};
}
pub fn packMap(writer: anytype, size: usize) Error(@TypeOf(writer).Error)!void {
    switch (size) {
        0...15 => |len| try writer.writeByte(0b1000_0000 | @as(u8, @intCast(len))),
        16...maxInt(u16) => |len| {
            try writer.writeByte(0xDE);
            try writeWithEndian(target_endian, writer, @as(u16, @intCast(len)));
        },
        maxInt(u16) + 1...maxInt(u32) => |len| {
            try writer.writeByte(0xDF);
            try writeWithEndian(target_endian, writer, @as(u32, @intCast(len)));
        },
        else => return error.MapTooLong,
    }
}

test "packArray" {
    const expect = @import("utils.zig").expect;

    try expect(packMap, 0, &[_]u8{0x80});
    try expect(packMap, 15, &[_]u8{0x8F});
    try expect(packMap, 16, &[_]u8{ 0xDE, 0x00, 0x10 });
    try expect(packMap, maxInt(u16), &[_]u8{ 0xDE, 0xFF, 0xFF });
    try expect(packMap, maxInt(u16) + 1, &[_]u8{ 0xDF, 0x00, 0x01, 0x00, 0x00 });
    try expect(packMap, maxInt(u32), &[_]u8{ 0xDF, 0xFF, 0xFF, 0xFF, 0xFF });
    try expect(packMap, maxInt(u32) + 1, error.MapTooLong);
}
