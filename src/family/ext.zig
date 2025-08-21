pub const Ext = struct {
    const Self = @This();

    type: i8,
    len: u32,

    pub fn init(@"type": i8, len: u32) Ext {
        return .{ .type = @"type", .len = len };
    }

    pub fn mzgPack(self: Self, writer: *Writer) !void {
        return packExt(self, writer);
    }
    pub fn mzgUnpack(self: *Self, buffer: []const u8) UnpackError!usize {
        return unpackExt(self, buffer);
    }
};
pub fn packExt(ext: Ext, writer: *Writer) PackError!void {
    const maxInt = std.math.maxInt;

    switch (ext.len) {
        1 => try writer.writeAll(&[2]u8{ 0xD4, @bitCast(ext.type) }),
        2 => try writer.writeAll(&[2]u8{ 0xD5, @bitCast(ext.type) }),
        4 => try writer.writeAll(&[2]u8{ 0xD6, @bitCast(ext.type) }),
        8 => try writer.writeAll(&[2]u8{ 0xD7, @bitCast(ext.type) }),
        16 => try writer.writeAll(&[2]u8{ 0xD8, @bitCast(ext.type) }),
        0, 3, 5...7, 9...15, 17...maxInt(u8) => |size| {
            try writer.writeAll(&[3]u8{ 0xC7, @intCast(size), @bitCast(ext.type) });
        },
        maxInt(u8) + 1...maxInt(u16) => |size| {
            const buffer = utils.header(u16, 0xC8, @intCast(size)) ++ [1]u8{@bitCast(ext.type)};
            try writer.writeAll(&buffer);
        },
        maxInt(u16) + 1...maxInt(u32) => |size| {
            const buffer = utils.header(u32, 0xC9, @intCast(size)) ++ [1]u8{@bitCast(ext.type)};
            try writer.writeAll(&buffer);
        },
    }
}
pub fn unpackExt(out: *Ext, buffer: []const u8) UnpackError!usize {
    const format = try parseFormat(buffer);
    switch (format) {
        .ext => |ext| switch (ext) {
            .fix1 => {
                if (buffer.len < 2) {
                    return UnpackError.BufferUnderRun;
                }
                out.type = @bitCast(buffer[1]);
                out.len = 1;
                return 2;
            },
            .fix2 => {
                if (buffer.len < 2) {
                    return UnpackError.BufferUnderRun;
                }
                out.type = @bitCast(buffer[1]);
                out.len = 2;
                return 2;
            },
            .fix4 => {
                if (buffer.len < 2) {
                    return UnpackError.BufferUnderRun;
                }
                out.type = @bitCast(buffer[1]);
                out.len = 4;
                return 2;
            },
            .fix8 => {
                if (buffer.len < 2) {
                    return UnpackError.BufferUnderRun;
                }
                out.type = @bitCast(buffer[1]);
                out.len = 8;
                return 2;
            },
            .fix16 => {
                if (buffer.len < 2) {
                    return UnpackError.BufferUnderRun;
                }
                out.type = @bitCast(buffer[1]);
                out.len = 16;
                return 2;
            },
            .ext8 => {
                if (buffer.len < 3) {
                    return UnpackError.BufferUnderRun;
                }
                out.type = @bitCast(buffer[2]);
                out.len = buffer[1];
                return 3;
            },
            .ext16 => {
                if (buffer.len < 4) {
                    return UnpackError.BufferUnderRun;
                }
                out.type = @bitCast(buffer[3]);
                out.len = std.mem.readInt(u16, buffer[1..3], .big);
                return 4;
            },
            .ext32 => {
                if (buffer.len < 6) {
                    return UnpackError.BufferUnderRun;
                }
                out.type = @bitCast(buffer[5]);
                out.len = std.mem.readInt(u32, buffer[1..5], .big);
                return 4;
            },
        },
        else => return UnpackError.TypeIncompatible,
    }
}

pub const Timestamp = struct {
    const Self = @This();

    sec: i64,
    nano: u32,

    pub fn fromNano(value: i128) Self {
        return from(std.time.ns_per_s, 1, value);
    }
    pub fn fromMicro(value: i64) Self {
        return from(std.time.us_per_s, std.time.ns_per_us, value);
    }
    pub fn fromMilli(value: i64) Self {
        return from(std.time.ms_per_s, std.time.ns_per_ms, value);
    }
    pub fn fromSec(value: i64) Self {
        return .{ .sec = value, .nano = 0 };
    }

    fn from(
        comptime second_scale: comptime_int,
        comptime nano_scale: comptime_int,
        value: anytype,
    ) Self {
        const Value = @TypeOf(value);
        switch (Value) {
            i64, i128 => {},
            else => @compileError(@typeName(Value) ++ " is not supported"),
        }
        const sec: i64 = @intCast(@divFloor(value, second_scale));
        const nano: u32 = @intCast((value - (sec * second_scale)) * nano_scale);
        return .{
            .sec = sec,
            .nano = nano,
        };
    }

    pub fn mzgPack(
        self: Self,
        _: PackOptions,
        comptime _: anytype,
        writer: *Writer,
    ) !void {
        return packTimestamp(self, writer);
    }
    pub fn mzgUnpack(
        out: *Self,
        comptime _: anytype,
        buffer: []const u8,
    ) UnpackError!usize {
        return unpackTimestamp(out, buffer);
    }
};

pub fn packTimestamp(value: Timestamp, writer: *Writer) PackError!void {
    const maxInt = std.math.maxInt;

    if (value.nano > 999_999_999) {
        return error.ValueInvalid;
    }

    if (value.nano == 0 and 0 <= value.sec and value.sec <= maxInt(u32)) {
        var content = [_]u8{ 0xD6, 0xFF } ++ [1]u8{0} ** 4;
        std.mem.writeInt(u32, content[2..], @intCast(value.sec), .big);
        try writer.writeAll(&content);
    } else if (0 <= value.sec and value.sec <= maxInt(u34)) {
        var content = [_]u8{ 0xD7, 0xFF } ++ [1]u8{0} ** 8;
        std.mem.writeInt(
            u64,
            content[2..],
            @shlExact(@as(u64, value.nano), 34) | @as(u64, @intCast(value.sec)),
            .big,
        );
        try writer.writeAll(&content);
    } else {
        var content = [_]u8{ 0xC7, 0x0C, 0xFF } ++ [1]u8{0} ** 12;
        std.mem.writeInt(u32, content[3..7], value.nano, .big);
        std.mem.writeInt(i64, content[7..], value.sec, .big);
        try writer.writeAll(&content);
    }
}

pub fn unpackTimestamp(out: *Timestamp, buffer: []const u8) UnpackError!usize {
    const ext, const size = ext: {
        var result: Ext = undefined;
        const size = try result.mzgUnpack(buffer);
        break :ext .{ result, size };
    };

    if (ext.type != -1) {
        return UnpackError.TypeIncompatible;
    }

    if (buffer.len < size + ext.len) {
        return UnpackError.BufferUnderRun;
    }

    switch (ext.len) {
        4 => {
            out.nano = 0;
            out.sec = std.mem.readInt(u32, buffer[2..6], .big);
        },
        8 => {
            out.nano = @shrExact(
                std.mem.readInt(u32, buffer[2..6], .big) & 0xFF_FF_FF_FC,
                2,
            );
            out.sec = std.mem.readInt(u40, buffer[5..10], .big) & 0x3_FF_FF_FF_FF;
        },
        12 => {
            out.nano = std.mem.readInt(u32, buffer[3..7], .big);
            out.sec = std.mem.readInt(i64, buffer[7..15], .big);
        },
        else => return UnpackError.TypeIncompatible,
    }

    return size + ext.len;
}

const builtin = @import("builtin");

const std = @import("std");
const Writer = std.io.Writer;

const utils = @import("../utils.zig");
const parseFormat = @import("format.zig").parse;
const PackError = @import("../error.zig").PackError;
const PackOptions = @import("../root.zig").PackOptions;
const UnpackError = @import("../error.zig").UnpackError;
