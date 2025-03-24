pub fn packBool(
    writer: anytype,
    value: bool,
) @TypeOf(writer).Error!void {
    try writer.writeAll(&[_]u8{if (value) 0xC3 else 0xC2});
}
