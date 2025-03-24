const std = @import("std");
const maxInt = std.math.maxInt;

const builtin = @import("builtin");
const target_endian = builtin.target.cpu.arch.endian();

const utils = @import("utils.zig");
const asBigEndianBytes = utils.asBigEndianBytes;

pub const Ext = struct {
    type: i8,
    size: u32,

    pub fn init(@"type": i8, size: u32) Ext {
        return .{ .type = @"type", .size = size };
    }
};
pub fn PackError(WriterError: type) type {
    return WriterError || error{ExtTooLong};
}
pub fn packExt(writer: anytype, ext: Ext) PackError(@TypeOf(writer).Error)!void {
    switch (ext.size) {
        1 => try writer.writeAll(&[2]u8{ 0xD4, @bitCast(ext.type) }),
        2 => try writer.writeAll(&[2]u8{ 0xD5, @bitCast(ext.type) }),
        4 => try writer.writeAll(&[2]u8{ 0xD6, @bitCast(ext.type) }),
        8 => try writer.writeAll(&[2]u8{ 0xD7, @bitCast(ext.type) }),
        16 => try writer.writeAll(&[2]u8{ 0xD8, @bitCast(ext.type) }),
        0, 3, 5...7, 9...15, 17...maxInt(u8) => |size| {
            try writer.writeAll(&[3]u8{ 0xC7, @intCast(size), @bitCast(ext.type) });
        },
        maxInt(u8) + 1...maxInt(u16) => |size| {
            const buffer = [_]u8{0xC8} // marker
                ++ asBigEndianBytes(target_endian, @as(u16, @intCast(size))) // size
                ++ [_]u8{@bitCast(ext.type)}; // type
            try writer.writeAll(&buffer);
        },
        maxInt(u16) + 1...maxInt(u32) => |size| {
            const buffer = [_]u8{0xC9} // marker
                ++ asBigEndianBytes(target_endian, size) // size
                ++ [_]u8{@bitCast(ext.type)}; // type
            try writer.writeAll(&buffer);
        },
    }
}

test "packExt" {
    const expect = @import("utils.zig").expect;

    try expect(packExt, Ext.init(1, 1), &[_]u8{ 0xD4, 0x01 });
    try expect(packExt, Ext.init(1, 2), &[_]u8{ 0xD5, 0x01 });
    try expect(packExt, Ext.init(1, 4), &[_]u8{ 0xD6, 0x01 });
    try expect(packExt, Ext.init(1, 8), &[_]u8{ 0xD7, 0x01 });
    try expect(packExt, Ext.init(1, 16), &[_]u8{ 0xD8, 0x01 });
    try expect(packExt, Ext.init(1, 0), &[_]u8{ 0xC7, 0x00, 0x01 });
    try expect(packExt, Ext.init(1, 3), &[_]u8{ 0xC7, 0x03, 0x01 });
    try expect(packExt, Ext.init(1, 5), &[_]u8{ 0xC7, 0x05, 0x01 });
    try expect(packExt, Ext.init(1, maxInt(u8)), &[_]u8{ 0xC7, 0xFF, 0x01 });
    try expect(packExt, Ext.init(1, maxInt(u16) - 1), &[_]u8{ 0xC8, 0xFF, 0xFE, 0x01 });
    try expect(packExt, Ext.init(1, maxInt(u32) - 1), &[_]u8{ 0xC9, 0xFF, 0xFF, 0xFF, 0xFE, 0x01 });
}
