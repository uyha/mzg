test "packArray" {
    const expect = @import("utils.zig").expect;

    const std = @import("std");
    const maxInt = std.math.maxInt;
    const packMap = @import("mzg").packMap;

    try expect(packMap, &[_]u8{0x80}, 0);
    try expect(packMap, &[_]u8{0x8F}, 15);
    try expect(packMap, &[_]u8{ 0xDE, 0x00, 0x10 }, 16);
    try expect(packMap, &[_]u8{ 0xDE, 0xFF, 0xFF }, maxInt(u16));
    try expect(packMap, &[_]u8{ 0xDF, 0x00, 0x01, 0x00, 0x00 }, maxInt(u16) + 1);
    try expect(packMap, &[_]u8{ 0xDF, 0xFF, 0xFF, 0xFF, 0xFF }, maxInt(u32));
    try expect(packMap, error.ValueInvalid, maxInt(u32) + 1);
}
