test "packStr" {
    // Cannot actually test for 2 ^ 32 long string since the compilation just freezes
    const expect = @import("../utils.zig").expect;

    const maxInt = @import("std").math.maxInt;
    const packStr = @import("mzg").packStr;

    try expect(
        packStr,
        &[_]u8{ 0xA4, 0x31, 0x32, 0x33, 0x34 },
        "1234",
    );
    try expect(
        packStr,
        &([_]u8{ 0xD9, 0xFF } ++ @as([maxInt(u8)]u8, @splat(0x31))),
        &@as([maxInt(u8)]u8, @splat(0x31)),
    );
    try expect(
        packStr,
        &([_]u8{ 0xDA, 0xFF, 0xFF } ++ @as([maxInt(u16)]u8, @splat(0x31))),
        &@as([maxInt(u16)]u8, @splat(0x31)),
    );
    try expect(
        packStr,
        &([_]u8{ 0xDB, 0x00, 0x01, 0x00, 0x00 } ++ @as([maxInt(u16) + 1]u8, @splat(0x31))),
        &@as([maxInt(u16) + 1]u8, @splat(0x31)),
    );
}
