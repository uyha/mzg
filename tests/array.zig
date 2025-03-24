test "packArray" {
    const expect = @import("utils.zig").expect;

    const maxInt = @import("std").math.maxInt;
    const packArray = @import("zmgp").packArray;

    try expect(packArray, 0, &[_]u8{0x90});
    try expect(packArray, 15, &[_]u8{0x9F});
    try expect(packArray, 16, &[_]u8{ 0xDC, 0x00, 0x10 });
    try expect(packArray, maxInt(u16), &[_]u8{ 0xDC, 0xFF, 0xFF });
    try expect(packArray, maxInt(u16) + 1, &[_]u8{ 0xDD, 0x00, 0x01, 0x00, 0x00 });
    try expect(packArray, maxInt(u32), &[_]u8{ 0xDD, 0xFF, 0xFF, 0xFF, 0xFF });
    try expect(packArray, maxInt(u32) + 1, error.ArrayTooLong);
}
