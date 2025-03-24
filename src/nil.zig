pub fn packNil(
    writer: anytype,
) @TypeOf(writer).Error!void {
    try writer.writeAll(&[_]u8{0xC0});
}
