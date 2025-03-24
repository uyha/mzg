test "packArray" {
    const expect = @import("utils.zig").expect;

    const std = @import("std");
    const maxInt = std.math.maxInt;
    const packMap = @import("zmgp").packMap;

    try expect(packMap, 0, &[_]u8{0x80});
    try expect(packMap, 15, &[_]u8{0x8F});
    try expect(packMap, 16, &[_]u8{ 0xDE, 0x00, 0x10 });
    try expect(packMap, maxInt(u16), &[_]u8{ 0xDE, 0xFF, 0xFF });
    try expect(packMap, maxInt(u16) + 1, &[_]u8{ 0xDF, 0x00, 0x01, 0x00, 0x00 });
    try expect(packMap, maxInt(u32), &[_]u8{ 0xDF, 0xFF, 0xFF, 0xFF, 0xFF });
    try expect(packMap, maxInt(u32) + 1, error.MapTooLong);
}
