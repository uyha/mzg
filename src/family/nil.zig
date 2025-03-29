pub fn packNil(writer: anytype) @TypeOf(writer).Error!void {
    try writer.writeAll(&[_]u8{0xC0});
}

const UnpackError = @import("../error.zig").UnpackError;
const format = @import("format.zig");
pub fn unpackNil(buffer: []const u8, out: *void) UnpackError!usize {
    return switch (try format.parse(buffer)) {
        .nil => {
            out.* = {};
            return 1;
        },
        else => return UnpackError.TypeIncompatible,
    };
}
