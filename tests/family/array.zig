test "packArray" {
    const expect = @import("../utils.zig").expect;

    const maxInt = @import("std").math.maxInt;
    const packArray = @import("mzg").packArray;

    try expect(packArray, &[_]u8{0x90}, 0);
    try expect(packArray, &[_]u8{0x9F}, 15);
    try expect(packArray, &[_]u8{ 0xDC, 0x00, 0x10 }, 16);
    try expect(packArray, &[_]u8{ 0xDC, 0xFF, 0xFF }, maxInt(u16));
    try expect(packArray, &[_]u8{ 0xDD, 0x00, 0x01, 0x00, 0x00 }, maxInt(u16) + 1);
    try expect(packArray, &[_]u8{ 0xDD, 0xFF, 0xFF, 0xFF, 0xFF }, maxInt(u32));
    try expect(packArray, error.ValueInvalid, maxInt(u32) + 1);
}
