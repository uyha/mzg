pub fn packBool(
    writer: anytype,
    value: bool,
) @TypeOf(writer).Error!void {
    try writer.writeByte(if (value) 0xC3 else 0xC2);
}

test "packBool" {
    const expect = @import("utils.zig").expect;
    try expect(packBool, false, &[_]u8{0xC2});
    try expect(packBool, true, &[_]u8{0xC3});
}
