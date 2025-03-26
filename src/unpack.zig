const std = @import("std");
const UnpackError = @import("error.zig").UnpackError;
const Array = enum {
    fix,
    arr16,
    arr32,

    const Self = @This();
    pub fn size(self: Self) usize {
        return switch (self) {
            .fix => 0,
            .arr16 => 2,
            .arr32 => 4,
        };
    }
};
const Map = enum {
    fix,
    map16,
    map32,

    const Self = @This();
    pub fn size(self: Self) usize {
        return switch (self) {
            .fix => 0,
            .map16 => 2,
            .map32 => 4,
        };
    }
};
const Ext = enum {
    fix1,
    fix2,
    fix4,
    fix8,
    fix16,
    ext8,
    ext16,
    ext32,

    const Self = @This();
    pub fn size(self: Self) usize {
        return switch (self) {
            .fix1, .fix2, .fix4, .fix8, .fix16 => 0,
            .ext8 => 1,
            .ext16 => 2,
            .ext32 => 4,
        };
    }
};

pub const Format = union(enum) {
    nil: void,
    bool: bool,
    int: @import("family/int.zig").Int,
    float: @import("family/float.zig").Float,
    str: @import("family/str.zig").Str,
    bin: @import("family/bin.zig").Bin,
    array: Array,
    map: Map,
    ext: Ext,

    const Self = @This();
    pub fn size(self: Self) usize {
        return switch (self) {
            .nil, .bool => 0,
            inline else => |value| value.size(),
        };
    }
};

pub fn parseFormat(buffer: []const u8) UnpackError!Format {
    if (buffer.len < 1) {
        return UnpackError.BufferUnderRun;
    }

    return switch (buffer[0]) {
        0xC0 => .{ .nil = {} },
        0xC2, 0xC3 => |marker| .{ .bool = marker == 0xC3 },
        0...0x7F => .{ .int = .pos },
        0xE0...0xFF => .{ .int = .neg },
        0xCC => .{ .int = .u8 },
        0xCD => .{ .int = .u16 },
        0xCE => .{ .int = .u32 },
        0xCF => .{ .int = .u64 },
        0xD0 => .{ .int = .i8 },
        0xD1 => .{ .int = .i16 },
        0xD2 => .{ .int = .i32 },
        0xD3 => .{ .int = .i64 },
        0xCA => .{ .float = .f32 },
        0xCB => .{ .float = .f64 },
        0xA0...0xBF => .{ .str = .fix },
        0xD9 => .{ .str = .str8 },
        0xDA => .{ .str = .str16 },
        0xDB => .{ .str = .str32 },
        0xC4 => .{ .bin = .bin8 },
        0xC5 => .{ .bin = .bin16 },
        0xC6 => .{ .bin = .bin32 },
        0x90...0x9F => .{ .array = .fix },
        0xDC => .{ .array = .arr16 },
        0xDD => .{ .array = .arr32 },
        0x80...0x8F => .{ .array = .fix },
        0xDE => .{ .map = .map16 },
        0xDF => .{ .map = .map32 },
        0xD4 => .{ .ext = .fix1 },
        0xD5 => .{ .ext = .fix2 },
        0xD6 => .{ .ext = .fix4 },
        0xD7 => .{ .ext = .fix8 },
        0xD8 => .{ .ext = .fix16 },
        0xC7 => .{ .ext = .ext8 },
        0xC8 => .{ .ext = .ext16 },
        0xC9 => .{ .ext = .ext32 },
        else => UnpackError.FormatUnrecognized,
    };
}

pub fn unpack(buffer: []const u8, out: anytype) UnpackError!usize {
    const Out = @TypeOf(out);
    const info = @typeInfo(Out);
    if (comptime info != .pointer or info.pointer.size != .one) {
        @compileError("`out` has to be a singe-item pointer");
    }
    const Child = info.pointer.child;

    switch (@typeInfo(Child)) {
        .void => switch (try parseFormat(buffer)) {
            .nil => {
                out.* = {};
                return 1;
            },
            else => return UnpackError.TypeIncompatible,
        },
        .null => switch (try parseFormat(buffer)) {
            .nil => {
                out.* = null;
                return 1;
            },
            else => return UnpackError.TypeIncompatible,
        },
        .bool => return switch (try parseFormat(buffer)) {
            .bool => |value| {
                out.* = value;
                return 1;
            },
            else => return UnpackError.TypeIncompatible,
        },
        .int => return @import("family/int.zig").unpackInt(buffer, out),
        .float => return @import("family/float.zig").unpackFloat(buffer, out),
        .optional => switch (try parseFormat(buffer)) {
            .nil => {
                out.* = null;
                return 1;
            },
            else => {
                out.* = undefined;
                return unpack(buffer, &out.*.?);
            },
        },
        .@"enum" => |E| {
            if (std.meta.hasFn(Child, "mzgUnpack")) {
                return Child.mzgUnpack(buffer, out);
            }

            const format = try parseFormat(buffer);

            switch (format) {
                .int => {
                    var raw: E.tag_type = undefined;
                    if (unpack(buffer, &raw)) |size| {
                        out.* = std.meta.intToEnum(
                            Child,
                            raw,
                        ) catch return UnpackError.ValueInvalid;
                        return size;
                    } else |err| {
                        return err;
                    }
                },
                .str => {
                    var view: []const u8 = undefined;
                    const size = try unpack(buffer, &view);
                    out.* = std.meta.stringToEnum(
                        Child,
                        view,
                    ) orelse return UnpackError.ValueInvalid;
                    return size;
                },
                else => return UnpackError.TypeIncompatible,
            }
        },
        .pointer => |ptr| switch (ptr.size) {
            .slice => {
                if (ptr.child == u8) {
                    const format = try parseFormat(buffer);
                    return switch (format) {
                        .str => @import("family/str.zig").unpackStr(buffer, out),
                        .bin => @import("family/bin.zig").unpackBin(buffer, out),
                        else => UnpackError.TypeIncompatible,
                    };
                } else {
                    @compileError("'" ++ @typeName(Out) ++ "' is not supported");
                }
            },
            else => @compileError("'" ++ @typeName(Out) ++ "' is not supported"),
        },
        else => @compileError("'" ++ @typeName(Out) ++ "' is not supported"),
    }
}
