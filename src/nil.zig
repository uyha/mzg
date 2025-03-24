pub fn packNil(
    writer: anytype,
) @TypeOf(writer).Error!void {
    try writer.writeByte(0xC0);
}

test "packNil" {
    const expect = @import("utils.zig").expect;
    try expect(packNil, {}, &[_]u8{0xC0});
}
