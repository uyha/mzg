pub fn packBool(
    value: bool,
    writer: anytype,
) @TypeOf(writer).Error!void {
    try writer.writeAll(&[_]u8{if (value) 0xC3 else 0xC2});
}

const UnpackError = @import("error.zig").UnpackError;
const parseFormat = @import("format.zig").parse;
pub fn unpackBool(buffer: []const u8, out: *bool) UnpackError!usize {
    return switch (try parseFormat(buffer)) {
        .bool => |value| {
            out.* = value;
            return 1;
        },
        else => return UnpackError.TypeIncompatible,
    };
}
