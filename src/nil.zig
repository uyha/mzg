pub fn packNil(
    writer: anytype,
) @TypeOf(writer).Error!void {
    try writer.writeByte(0xC0);
}
