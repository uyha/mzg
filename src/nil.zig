const PackError = @import("error.zig").PackError;

pub fn packNil(
    writer: anytype,
) PackError(@TypeOf(writer))!void {
    try writer.writeAll(&[_]u8{0xC0});
}
