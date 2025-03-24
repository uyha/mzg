const std = @import("std");

const builtin = @import("builtin");
const target_endian = builtin.target.cpu.arch.endian();

const utils = @import("utils.zig");
const asBigEndianBytes = utils.asBigEndianBytes;

pub fn Error(WriterError: type) type {
    return WriterError || error{StringTooLong};
}
pub fn packStr(writer: anytype, input: []const u8) Error(@TypeOf(writer).Error)!void {
    switch (input.len) {
        0...31 => {
            try writer.writeByte(0b1010_0000 | @as(u8, @intCast(input.len)));
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

test "packStr" {
    // Cannot actually test for 2 ^ 32 long string since the compilation just freezes
    const expect = @import("utils.zig").expect;

    try expect(
        packStr,
        "1234",
        &[_]u8{ 0xA4, 0x31, 0x32, 0x33, 0x34 },
    );
    try expect(
        packStr,
        &[1]u8{0x31} ** std.math.maxInt(u8),
        &([_]u8{ 0xD9, 0xFF } ++ [1]u8{0x31} ** std.math.maxInt(u8)),
    );
    try expect(
        packStr,
        &[1]u8{0x31} ** std.math.maxInt(u16),
        &([_]u8{ 0xDA, 0xFF, 0xFF } ++ [1]u8{0x31} ** std.math.maxInt(u16)),
    );
    try expect(
        packStr,
        &[1]u8{0x31} ** (std.math.maxInt(u16) + 1),
        &([_]u8{ 0xDB, 0x00, 0x01, 0x00, 0x00 } ++ [1]u8{0x31} ** (std.math.maxInt(u16) + 1)),
    );
}
