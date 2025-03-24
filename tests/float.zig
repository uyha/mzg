test "packFloat" {
    const expect = @import("utils.zig").expect;

    const packFloat = @import("zmgp").packFloat;

    try expect(
        packFloat,
        @as(f16, 1.0),
        &[_]u8{ 0xCA, 0x3F, 0x80, 0x00, 0x00 },
    );
    try expect(
        packFloat,
        @as(f32, 1.0),
        &[_]u8{ 0xCA, 0x3F, 0x80, 0x00, 0x00 },
    );
    try expect(
        packFloat,
        1.0,
        &[_]u8{ 0xCB, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
    );
    try expect(
        packFloat,
        @as(f64, 1.0),
        &[_]u8{ 0xCB, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
    );
}
