test "packInt" {
    const expect = @import("utils.zig").expect;

    const std = @import("std");
    const maxInt = std.math.maxInt;
    const minInt = std.math.minInt;

    const packInt = @import("zmgp").packInt;

    // u8
    try expect(packInt, &[_]u8{0x00}, @as(u8, 0));
    try expect(packInt, &[_]u8{0x7E}, @as(u8, 126));
    try expect(packInt, &[_]u8{0x7F}, @as(u8, 127));
    try expect(packInt, &[_]u8{ 0xCC, 0x80 }, @as(u8, 128));
    try expect(packInt, &[_]u8{ 0xCC, 0xFF }, @as(u8, 255));

    // u16
    try expect(packInt, &[_]u8{0x00}, @as(u16, 0));
    try expect(packInt, &[_]u8{ 0xCC, 0xFF }, @as(u16, maxInt(u8)));
    try expect(packInt, &[_]u8{ 0xCD, 0x01, 0x00 }, @as(u16, maxInt(u8) + 1));
    try expect(packInt, &[_]u8{ 0xCD, 0xFF, 0xFF }, @as(u16, maxInt(u16)));

    // u32
    try expect(packInt, &[_]u8{0x00}, @as(u32, 0));
    try expect(packInt, &[_]u8{ 0xCC, 0xFF }, @as(u32, maxInt(u8)));
    try expect(packInt, &[_]u8{ 0xCD, 0xFF, 0xFF }, @as(u32, maxInt(u16)));
    try expect(packInt, &[_]u8{ 0xCE, 0x00, 0x01, 0x00, 0x00 }, @as(u32, maxInt(u16) + 1));
    try expect(packInt, &[_]u8{ 0xCE, 0xFF, 0xFF, 0xFF, 0xFF }, @as(u32, maxInt(u32)));

    // u64
    try expect(packInt, &[_]u8{0x00}, @as(u64, 0));
    try expect(packInt, &[_]u8{ 0xCC, 0xFF }, @as(u64, maxInt(u8)));
    try expect(packInt, &[_]u8{ 0xCD, 0xFF, 0xFF }, @as(u64, maxInt(u16)));
    try expect(packInt, &[_]u8{ 0xCE, 0x00, 0x01, 0x00, 0x00 }, @as(u64, maxInt(u16) + 1));
    try expect(packInt, &[_]u8{ 0xCE, 0xFF, 0xFF, 0xFF, 0xFF }, @as(u64, maxInt(u32)));
    try expect(
        packInt,
        &[_]u8{ 0xCF, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00 },
        @as(u64, maxInt(u32) + 1),
    );
    try expect(
        packInt,
        &[_]u8{ 0xCF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
        @as(u64, maxInt(u64)),
    );

    try expect(packInt, &[_]u8{0x00}, @as(i8, 0));
    try expect(packInt, &[_]u8{0xFF}, @as(i8, -1));
    try expect(packInt, &[_]u8{0xE0}, @as(i8, -32));
    try expect(packInt, &[_]u8{0x7F}, @as(i8, maxInt(i8)));
    try expect(packInt, &[_]u8{ 0xD0, 0x80 }, @as(i8, minInt(i8)));

    try expect(packInt, &[_]u8{0x00}, @as(i16, 0));
    try expect(packInt, &[_]u8{0xFF}, @as(i16, -1));
    try expect(packInt, &[_]u8{0xE0}, @as(i16, -32));
    try expect(packInt, &[_]u8{0x7F}, @as(i16, maxInt(i8)));
    try expect(packInt, &[_]u8{ 0xD0, 0x80 }, @as(i16, minInt(i8)));
    try expect(packInt, &[_]u8{ 0xCC, 0x80 }, @as(i16, maxInt(i8) + 1));
    try expect(packInt, &[_]u8{ 0xD1, 0xFF, 0x7F }, @as(i16, minInt(i8) - 1));
    try expect(packInt, &[_]u8{ 0xCD, 0x7F, 0xFF }, @as(i16, maxInt(i16)));
    try expect(packInt, &[_]u8{ 0xD1, 0x80, 0x00 }, @as(i16, minInt(i16)));

    try expect(packInt, &[_]u8{0x00}, @as(i32, 0));
    try expect(packInt, &[_]u8{0xFF}, @as(i32, -1));
    try expect(packInt, &[_]u8{0xE0}, @as(i32, -32));
    try expect(packInt, &[_]u8{0x7F}, @as(i32, maxInt(i8)));
    try expect(packInt, &[_]u8{ 0xD0, 0x80 }, @as(i32, minInt(i8)));
    try expect(packInt, &[_]u8{ 0xCC, 0x80 }, @as(i32, maxInt(i8) + 1));
    try expect(packInt, &[_]u8{ 0xD1, 0xFF, 0x7F }, @as(i32, minInt(i8) - 1));
    try expect(packInt, &[_]u8{ 0xCD, 0x7F, 0xFF }, @as(i32, maxInt(i16)));
    try expect(packInt, &[_]u8{ 0xD1, 0x80, 0x00 }, @as(i32, minInt(i16)));
    try expect(packInt, &[_]u8{ 0xCD, 0x80, 0x00 }, @as(i32, maxInt(i16) + 1));
    try expect(packInt, &[_]u8{ 0xD2, 0xFF, 0xFF, 0x7F, 0xFF }, @as(i32, minInt(i16) - 1));
    try expect(
        packInt,
        &[_]u8{ 0xCE, 0x7F, 0xFF, 0xFF, 0xFF },
        @as(i32, maxInt(i32)),
    );
    try expect(
        packInt,
        &[_]u8{ 0xD2, 0x80, 0x00, 0x00, 0x00 },
        @as(i32, minInt(i32)),
    );

    try expect(packInt, &[_]u8{0x00}, @as(i64, 0));
    try expect(packInt, &[_]u8{0xFF}, @as(i64, -1));
    try expect(packInt, &[_]u8{0xE0}, @as(i64, -32));
    try expect(packInt, &[_]u8{0x7F}, @as(i64, maxInt(i8)));
    try expect(packInt, &[_]u8{ 0xD0, 0x80 }, @as(i64, minInt(i8)));
    try expect(packInt, &[_]u8{ 0xCC, 0x80 }, @as(i64, maxInt(i8) + 1));
    try expect(packInt, &[_]u8{ 0xD1, 0xFF, 0x7F }, @as(i64, minInt(i8) - 1));
    try expect(packInt, &[_]u8{ 0xCD, 0x7F, 0xFF }, @as(i64, maxInt(i16)));
    try expect(packInt, &[_]u8{ 0xD1, 0x80, 0x00 }, @as(i64, minInt(i16)));
    try expect(packInt, &[_]u8{ 0xCD, 0x80, 0x00 }, @as(i64, maxInt(i16) + 1));
    try expect(packInt, &[_]u8{ 0xD2, 0xFF, 0xFF, 0x7F, 0xFF }, @as(i64, minInt(i16) - 1));
    try expect(
        packInt,
        &[_]u8{ 0xCE, 0x7F, 0xFF, 0xFF, 0xFF },
        @as(i64, maxInt(i32)),
    );
    try expect(
        packInt,
        &[_]u8{ 0xD2, 0x80, 0x00, 0x00, 0x00 },
        @as(i64, minInt(i32)),
    );
    try expect(
        packInt,
        &[_]u8{ 0xCE, 0x80, 0x00, 0x00, 0x00 },
        @as(i64, maxInt(i32) + 1),
    );
    try expect(
        packInt,
        &[_]u8{ 0xD3, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0xFF, 0xFF, 0xFF },
        @as(i64, minInt(i32) - 1),
    );
    try expect(
        packInt,
        &[_]u8{ 0xCF, 0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
        @as(i64, maxInt(i64)),
    );
    try expect(
        packInt,
        &[_]u8{ 0xD3, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
        @as(i64, minInt(i64)),
    );
}
