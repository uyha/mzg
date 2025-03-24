test "packBin" {
    // Cannot actually test for 2 ^ 32 long bin since the compilation just freezes
    const expect = @import("../utils.zig").expect;

    const maxInt = @import("std").math.maxInt;
    const packBin = @import("zmgp").packBin;

    try expect(
        packBin,
        &[_]u8{ 0xC4, 0x04, 0x31, 0x32, 0x33, 0x34 },
        "1234",
    );
    try expect(
        packBin,
        &([_]u8{ 0xC4, 0xFF } ++ [1]u8{0x31} ** maxInt(u8)),
        &[1]u8{0x31} ** maxInt(u8),
    );
    try expect(
        packBin,
        &([_]u8{ 0xC5, 0xFF, 0xFF } ++ [1]u8{0x31} ** maxInt(u16)),
        &[1]u8{0x31} ** maxInt(u16),
    );
    try expect(
        packBin,
        &([_]u8{ 0xC6, 0x00, 0x01, 0x00, 0x00 } ++ [1]u8{0x31} ** (maxInt(u16) + 1)),
        &[1]u8{0x31} ** (maxInt(u16) + 1),
    );
}
