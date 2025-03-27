const builtin = @import("builtin");
const std = @import("std");
const utils = @import("utils.zig");

const PackError = @import("error.zig").PackError;

pub const Ext = struct {
    type: i8,
    size: u32,

    pub fn init(@"type": i8, size: u32) Ext {
        return .{ .type = @"type", .size = size };
    }
};
pub fn packExt(ext: Ext, writer: anytype) @TypeOf(writer).Error!void {
    const maxInt = std.math.maxInt;

    switch (ext.size) {
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

    pub fn mzgPack(self: Self, writer: anytype) !void {
        return packTimestamp(self, writer);
    }
};

pub fn packTimestamp(value: Timestamp, writer: anytype) PackError(@TypeOf(writer))!void {
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
