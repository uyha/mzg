test "packBin" {
    // Cannot actually test for 2 ^ 32 long bin since the compilation just freezes
    const expect = @import("../utils.zig").expect;

    const maxInt = @import("std").math.maxInt;
    const packBin = @import("mzg").packBin;

    try expect(
        packBin,
        &[_]u8{ 0xC4, 0x04, 0x31, 0x32, 0x33, 0x34 },
        "1234",
    );
    try expect(
        packBin,
        &([_]u8{ 0xC4, 0xFF } ++ @as([maxInt(u8)]u8, @splat(0x31))),
        &@as([maxInt(u8)]u8, @splat(0x31)),
    );
    try expect(
        packBin,
        &([_]u8{ 0xC5, 0xFF, 0xFF } ++ @as([maxInt(u16)]u8, @splat(0x31))),
        &@as([maxInt(u16)]u8, @splat(0x31)),
    );
    try expect(
        packBin,
        &([_]u8{ 0xC6, 0x00, 0x01, 0x00, 0x00 } ++ @as([maxInt(u16) + 1]u8, @splat(0x31))),
        &@as([maxInt(u16) + 1]u8, @splat(0x31)),
    );
}
