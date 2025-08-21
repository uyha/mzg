pub const Int = union(enum) {
    const Self = @This();

    u8: u8,
    u16: u16,
    u32: u32,
    u64: u64,
    i8: i8,
    i16: i16,
    i32: i32,
    i64: i64,

    pub fn mzgPack(self: Self, writer: *Writer) PackError!void {
        return switch (self) {
            inline else => |value| mzg.packInt(value, writer),
        };
    }
    pub fn mzgUnpack(self: *Self, buffer: []const u8) UnpackError!usize {
        const format = try mzg.format.parse(buffer);

        if (format != .int) {
            return UnpackError.TypeIncompatible;
        }

        switch (format.int) {
            .pos => self.* = .{ .u8 = undefined },
            .neg => self.* = .{ .i8 = undefined },
            .u8 => self.* = .{ .u8 = undefined },
            .u16 => self.* = .{ .u16 = undefined },
            .u32 => self.* = .{ .u32 = undefined },
            .u64 => self.* = .{ .u64 = undefined },
            .i8 => self.* = .{ .i8 = undefined },
            .i16 => self.* = .{ .i16 = undefined },
            .i32 => self.* = .{ .i32 = undefined },
            .i64 => self.* = .{ .i64 = undefined },
        }

        switch (self.*) {
            inline else => |*value| return mzg.unpackInt(buffer, value),
        }
    }
};
pub const Float = union(enum) {
    const Self = @This();

    f32: f32,
    f64: f64,

    pub fn mzgPack(self: Self, writer: *Writer) PackError!void {
        return switch (self) {
            inline else => |value| mzg.packFloat(value, writer),
        };
    }
    pub fn mzgUnpack(self: *Self, buffer: []const u8) UnpackError!usize {
        const format = try mzg.format.parse(buffer);

        if (format != .float) {
            return UnpackError.TypeIncompatible;
        }

        switch (format.float) {
            .f32 => self.* = .{ .f32 = undefined },
            .f64 => self.* = .{ .f64 = undefined },
        }

        switch (self.*) {
            inline else => |*value| return mzg.unpackFloat(buffer, value),
        }
    }
};

pub const Value = union(enum) {
    const Self = @This();

    array: usize,
    bin: []const u8,
    bool: bool,
    ext: Ext,
    float: Float,
    int: Int,
    map: usize,
    nil: void,
    str: []const u8,
    timestamp: Timestamp,

    pub fn mzgPack(self: Self, writer: *Writer) PackError!void {
        return switch (self) {
            inline else => |value| mzg.pack(value, writer),
        };
    }
    pub fn mzgUnpack(self: *Self, buffer: []const u8) UnpackError!usize {
        switch (try mzg.format.parse(buffer)) {
            .array => self.* = .{ .array = undefined },
            .bin => self.* = .{ .bin = undefined },
            .bool => self.* = .{ .bool = undefined },
            .ext => self.* = .{ .ext = undefined },
            .float => self.* = .{ .float = undefined },
            .int => self.* = .{ .int = undefined },
            .map => self.* = .{ .map = undefined },
            .nil => self.* = .{ .nil = undefined },
            .str => self.* = .{ .str = undefined },
        }

        var result = try switch (self.*) {
            inline else => |*value| mzg.unpack(buffer, value),
        };

        if (self.* == .ext and self.ext.type == -1) {
            self.* = .{ .timestamp = undefined };
            result = try mzg.unpackTimestamp(&self.timestamp, buffer);
        }

        return result;
    }
};

const std = @import("std");
const Writer = std.io.Writer;

const mzg = @import("root.zig");
const Ext = mzg.Ext;
const PackError = mzg.PackError;
const Timestamp = mzg.Timestamp;
const UnpackError = mzg.UnpackError;
