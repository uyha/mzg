pub fn packBool(
    writer: anytype,
    value: bool,
) @TypeOf(writer).Error!void {
    try writer.writeByte(if (value) 0xC3 else 0xC2);
}
