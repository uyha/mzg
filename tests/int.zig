test "packInt" {
    const expect = @import("utils.zig").expect;

    const std = @import("std");
    const maxInt = std.math.maxInt;
    const minInt = std.math.minInt;

    const packInt = @import("zmgp").packInt;

    // u8
    try expect(packInt, @as(u8, 0), &[_]u8{0x00});
    try expect(packInt, @as(u8, 126), &[_]u8{0x7E});
    try expect(packInt, @as(u8, 127), &[_]u8{0x7F});
    try expect(packInt, @as(u8, 128), &[_]u8{ 0xCC, 0x80 });
    try expect(packInt, @as(u8, 255), &[_]u8{ 0xCC, 0xFF });

    // u16
    try expect(packInt, @as(u16, 0), &[_]u8{0x00});
    try expect(packInt, @as(u16, maxInt(u8)), &[_]u8{ 0xCC, 0xFF });
    try expect(packInt, @as(u16, maxInt(u8) + 1), &[_]u8{ 0xCD, 0x01, 0x00 });
    try expect(packInt, @as(u16, maxInt(u16)), &[_]u8{ 0xCD, 0xFF, 0xFF });

    // u32
    try expect(packInt, @as(u32, 0), &[_]u8{0x00});
    try expect(packInt, @as(u32, maxInt(u8)), &[_]u8{ 0xCC, 0xFF });
    try expect(packInt, @as(u32, maxInt(u16)), &[_]u8{ 0xCD, 0xFF, 0xFF });
    try expect(packInt, @as(u32, maxInt(u16) + 1), &[_]u8{ 0xCE, 0x00, 0x01, 0x00, 0x00 });
    try expect(packInt, @as(u32, maxInt(u32)), &[_]u8{ 0xCE, 0xFF, 0xFF, 0xFF, 0xFF });

    // u64
    try expect(packInt, @as(u64, 0), &[_]u8{0x00});
    try expect(packInt, @as(u64, maxInt(u8)), &[_]u8{ 0xCC, 0xFF });
    try expect(packInt, @as(u64, maxInt(u16)), &[_]u8{ 0xCD, 0xFF, 0xFF });
    try expect(packInt, @as(u64, maxInt(u16) + 1), &[_]u8{ 0xCE, 0x00, 0x01, 0x00, 0x00 });
    try expect(packInt, @as(u64, maxInt(u32)), &[_]u8{ 0xCE, 0xFF, 0xFF, 0xFF, 0xFF });
    try expect(
        packInt,
        @as(u64, maxInt(u32) + 1),
        &[_]u8{ 0xCF, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00 },
    );
    try expect(
        packInt,
        @as(u64, maxInt(u64)),
        &[_]u8{ 0xCF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    );

    try expect(packInt, @as(i8, 0), &[_]u8{0x00});
    try expect(packInt, @as(i8, -1), &[_]u8{0xFF});
    try expect(packInt, @as(i8, -32), &[_]u8{0xE0});
    try expect(packInt, @as(i8, maxInt(i8)), &[_]u8{0x7F});
    try expect(packInt, @as(i8, minInt(i8)), &[_]u8{ 0xD0, 0x80 });

    try expect(packInt, @as(i16, 0), &[_]u8{0x00});
    try expect(packInt, @as(i16, -1), &[_]u8{0xFF});
    try expect(packInt, @as(i16, -32), &[_]u8{0xE0});
    try expect(packInt, @as(i16, maxInt(i8)), &[_]u8{0x7F});
    try expect(packInt, @as(i16, minInt(i8)), &[_]u8{ 0xD0, 0x80 });
    try expect(packInt, @as(i16, maxInt(i8) + 1), &[_]u8{ 0xCC, 0x80 });
    try expect(packInt, @as(i16, minInt(i8) - 1), &[_]u8{ 0xD1, 0xFF, 0x7F });
    try expect(packInt, @as(i16, maxInt(i16)), &[_]u8{ 0xCD, 0x7F, 0xFF });
    try expect(packInt, @as(i16, minInt(i16)), &[_]u8{ 0xD1, 0x80, 0x00 });

    try expect(packInt, @as(i32, 0), &[_]u8{0x00});
    try expect(packInt, @as(i32, -1), &[_]u8{0xFF});
    try expect(packInt, @as(i32, -32), &[_]u8{0xE0});
    try expect(packInt, @as(i32, maxInt(i8)), &[_]u8{0x7F});
    try expect(packInt, @as(i32, minInt(i8)), &[_]u8{ 0xD0, 0x80 });
    try expect(packInt, @as(i32, maxInt(i8) + 1), &[_]u8{ 0xCC, 0x80 });
    try expect(packInt, @as(i32, minInt(i8) - 1), &[_]u8{ 0xD1, 0xFF, 0x7F });
    try expect(packInt, @as(i32, maxInt(i16)), &[_]u8{ 0xCD, 0x7F, 0xFF });
    try expect(packInt, @as(i32, minInt(i16)), &[_]u8{ 0xD1, 0x80, 0x00 });
    try expect(packInt, @as(i32, maxInt(i16) + 1), &[_]u8{ 0xCD, 0x80, 0x00 });
    try expect(packInt, @as(i32, minInt(i16) - 1), &[_]u8{ 0xD2, 0xFF, 0xFF, 0x7F, 0xFF });
    try expect(
        packInt,
        @as(i32, maxInt(i32)),
        &[_]u8{ 0xCE, 0x7F, 0xFF, 0xFF, 0xFF },
    );
    try expect(
        packInt,
        @as(i32, minInt(i32)),
        &[_]u8{ 0xD2, 0x80, 0x00, 0x00, 0x00 },
    );

    try expect(packInt, @as(i64, 0), &[_]u8{0x00});
    try expect(packInt, @as(i64, -1), &[_]u8{0xFF});
    try expect(packInt, @as(i64, -32), &[_]u8{0xE0});
    try expect(packInt, @as(i64, maxInt(i8)), &[_]u8{0x7F});
    try expect(packInt, @as(i64, minInt(i8)), &[_]u8{ 0xD0, 0x80 });
    try expect(packInt, @as(i64, maxInt(i8) + 1), &[_]u8{ 0xCC, 0x80 });
    try expect(packInt, @as(i64, minInt(i8) - 1), &[_]u8{ 0xD1, 0xFF, 0x7F });
    try expect(packInt, @as(i64, maxInt(i16)), &[_]u8{ 0xCD, 0x7F, 0xFF });
    try expect(packInt, @as(i64, minInt(i16)), &[_]u8{ 0xD1, 0x80, 0x00 });
    try expect(packInt, @as(i64, maxInt(i16) + 1), &[_]u8{ 0xCD, 0x80, 0x00 });
    try expect(packInt, @as(i64, minInt(i16) - 1), &[_]u8{ 0xD2, 0xFF, 0xFF, 0x7F, 0xFF });
    try expect(
        packInt,
        @as(i64, maxInt(i32)),
        &[_]u8{ 0xCE, 0x7F, 0xFF, 0xFF, 0xFF },
    );
    try expect(
        packInt,
        @as(i64, minInt(i32)),
        &[_]u8{ 0xD2, 0x80, 0x00, 0x00, 0x00 },
    );
    try expect(
        packInt,
        @as(i64, maxInt(i32) + 1),
        &[_]u8{ 0xCE, 0x80, 0x00, 0x00, 0x00 },
    );
    try expect(
        packInt,
        @as(i64, minInt(i32) - 1),
        &[_]u8{ 0xD3, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0xFF, 0xFF, 0xFF },
    );
    try expect(
        packInt,
        @as(i64, maxInt(i64)),
        &[_]u8{ 0xCF, 0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    );
    try expect(
        packInt,
        @as(i64, minInt(i64)),
        &[_]u8{ 0xD3, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
    );
}
