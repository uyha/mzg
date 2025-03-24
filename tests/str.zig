test "packStr" {
    // Cannot actually test for 2 ^ 32 long string since the compilation just freezes
    const expect = @import("utils.zig").expect;

    const maxInt = @import("std").math.maxInt;
    const packStr = @import("zmgp").packStr;

    try expect(
        packStr,
        "1234",
        &[_]u8{ 0xA4, 0x31, 0x32, 0x33, 0x34 },
    );
    try expect(
        packStr,
        &[1]u8{0x31} ** maxInt(u8),
        &([_]u8{ 0xD9, 0xFF } ++ [1]u8{0x31} ** maxInt(u8)),
    );
    try expect(
        packStr,
        &[1]u8{0x31} ** maxInt(u16),
        &([_]u8{ 0xDA, 0xFF, 0xFF } ++ [1]u8{0x31} ** maxInt(u16)),
    );
    try expect(
        packStr,
        &[1]u8{0x31} ** (maxInt(u16) + 1),
        &([_]u8{ 0xDB, 0x00, 0x01, 0x00, 0x00 } ++ [1]u8{0x31} ** (maxInt(u16) + 1)),
    );
}
