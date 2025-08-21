pub fn packBool(
    value: bool,
    writer: *Writer,
) PackError!void {
    try writer.writeAll(&[_]u8{if (value) 0xC3 else 0xC2});
}

pub fn unpackBool(buffer: []const u8, out: *bool) UnpackError!usize {
    return switch (try parseFormat(buffer)) {
        .bool => |value| {
            out.* = value;
            return 1;
        },
        else => return UnpackError.TypeIncompatible,
    };
}

const builtin = @import("builtin");

const std = @import("std");
const Writer = std.Io.Writer;

const PackError = @import("../error.zig").PackError;
const UnpackError = @import("../error.zig").UnpackError;
const parseFormat = @import("format.zig").parse;
const utils = @import("../utils.zig");
