const UnpackError = @import("error.zig").UnpackError;

pub const Array = enum { fix, arr16, arr32 };
pub const Bin = enum { bin8, bin16, bin32 };
pub const Ext = enum { fix1, fix2, fix4, fix8, fix16, ext8, ext16, ext32 };
pub const Float = enum { f32, f64 };
pub const Int = enum { pos, neg, u8, u16, u32, u64, i8, i16, i32, i64 };
pub const Map = enum { fix, map16, map32 };
pub const Str = enum { fix, str8, str16, str32 };

pub const Format = union(enum) {
    array: Array,
    bin: Bin,
    bool: bool,
    ext: Ext,
    float: Float,
    int: Int,
    map: Map,
    nil: void,
    str: Str,

    const Self = @This();
    pub fn size(self: Self) usize {
        return switch (self) {
            .nil, .bool => 0,
            inline else => |value| value.size(),
        };
    }
};

pub fn parse(buffer: []const u8) UnpackError!Format {
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
        0x80...0x8F => .{ .map = .fix },
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
