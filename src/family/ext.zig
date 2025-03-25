const std = @import("std");
const maxInt = std.math.maxInt;

const builtin = @import("builtin");

const utils = @import("../utils.zig");
const asBigEndianBytes = utils.asBigEndianBytes;

const PackError = @import("../error.zig").PackError;

pub const Ext = struct {
    type: i8,
    size: u32,

    pub fn init(@"type": i8, size: u32) Ext {
        return .{ .type = @"type", .size = size };
    }
};
pub fn packExt(writer: anytype, ext: Ext) PackError(@TypeOf(writer))!void {
    const target_endian = comptime builtin.target.cpu.arch.endian();
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
            const buffer = [_]u8{0xC8} // marker
                ++ asBigEndianBytes(target_endian, @as(u16, @intCast(size))) // size
                ++ [_]u8{@bitCast(ext.type)}; // type
            try writer.writeAll(&buffer);
        },
        maxInt(u16) + 1...maxInt(u32) => |size| {
            const buffer = [_]u8{0xC9} // marker
                ++ asBigEndianBytes(target_endian, size) // size
                ++ [_]u8{@bitCast(ext.type)}; // type
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

    pub fn mzgPack(self: Self, packer: anytype) !void {
        return packTimestamp(packer.writer, self);
    }
};

pub fn packTimestamp(
    writer: anytype,
    timestamp: Timestamp,
) PackError(@TypeOf(writer))!void {
    const target_endian = comptime builtin.target.cpu.arch.endian();

    if (timestamp.nano > 999_999_999) {
        return error.ValueInvalid;
    }

    if (timestamp.nano == 0 and 0 <= timestamp.sec and timestamp.sec <= maxInt(u32)) {
        try writer.writeAll(& //
            [_]u8{ 0xD6, @bitCast(@as(i8, @intCast(-1))) } // marker
            ++ asBigEndianBytes(target_endian, @as(u32, @intCast(timestamp.sec))) // value
        );
    } else if (0 <= timestamp.sec and timestamp.sec <= maxInt(u34)) {
        try writer.writeAll(& //
            [_]u8{ 0xD7, @bitCast(@as(i8, @intCast(-1))) } // marker
            ++ asBigEndianBytes(target_endian, @as(
                u64,
                @shlExact(@as(u64, timestamp.nano), 34) | @as(u64, @intCast(timestamp.sec)),
            )) // value
        );
    } else {
        try writer.writeAll(& //
            [_]u8{ 0xC7, 12, @bitCast(@as(i8, @intCast(-1))) } // marker
            ++ asBigEndianBytes(target_endian, timestamp.nano) // nanoseconds
            ++ asBigEndianBytes(target_endian, timestamp.sec) // seconds
        );
    }
}
