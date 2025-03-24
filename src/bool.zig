const PackError = @import("error.zig").PackError;

pub fn packBool(
    writer: anytype,
    value: bool,
) PackError(@TypeOf(writer))!void {
    try writer.writeAll(&[_]u8{if (value) 0xC3 else 0xC2});
}
