pub fn packNil(writer: *Writer) PackError!void {
    try writer.writeAll(&[_]u8{0xC0});
}

pub fn unpackNil(buffer: []const u8, out: *void) UnpackError!usize {
    return switch (try parseFormat(buffer)) {
        .nil => {
            out.* = {};
            return 1;
        },
        else => return UnpackError.TypeIncompatible,
    };
}

const std = @import("std");
const Writer = std.io.Writer;

const utils = @import("../utils.zig");
const parseFormat = @import("format.zig").parse;
const PackError = @import("../error.zig").PackError;
const UnpackError = @import("../error.zig").UnpackError;
