const std = @import("std");
const builtin = @import("builtin");

const utils = @import("utils.zig");
const asBigEndianBytes = utils.asBigEndianBytes;

pub fn PackError(WriterError: type) type {
    return WriterError || error{BinaryTooLong};
}
pub fn packBin(writer: anytype, input: []const u8) PackError(@TypeOf(writer).Error)!void {
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
        else => return error.BinaryTooLong,
    }
    try writer.writeAll(input);
}

test "packBin" {
    // Cannot actually test for 2 ^ 32 long bin since the compilation just freezes
    const expect = @import("utils.zig").expect;

    try expect(
        packBin,
        "1234",
        &[_]u8{ 0xC4, 0x04, 0x31, 0x32, 0x33, 0x34 },
    );
    try expect(
        packBin,
        &[1]u8{0x31} ** std.math.maxInt(u8),
        &([_]u8{ 0xC4, 0xFF } ++ [1]u8{0x31} ** std.math.maxInt(u8)),
    );
    try expect(
        packBin,
        &[1]u8{0x31} ** std.math.maxInt(u16),
        &([_]u8{ 0xC5, 0xFF, 0xFF } ++ [1]u8{0x31} ** std.math.maxInt(u16)),
    );
    try expect(
        packBin,
        &[1]u8{0x31} ** (std.math.maxInt(u16) + 1),
        &([_]u8{ 0xC6, 0x00, 0x01, 0x00, 0x00 } ++ [1]u8{0x31} ** (std.math.maxInt(u16) + 1)),
    );
}
