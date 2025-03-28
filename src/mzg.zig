pub const packArray = @import("array.zig").packArray;
pub const packBin = @import("bin.zig").packBin;
pub const packBool = @import("bool.zig").packBool;
pub const packFloat = @import("float.zig").packFloat;
pub const packInt = @import("int.zig").packInt;
pub const packMap = @import("map.zig").packMap;
pub const packNil = @import("nil.zig").packNil;
pub const packStr = @import("str.zig").packStr;

pub const unpackArray = @import("array.zig").unpackArray;
pub const unpackBin = @import("bin.zig").unpackBin;
pub const unpackBool = @import("bool.zig").unpackBool;
pub const unpackFloat = @import("float.zig").unpackFloat;
pub const unpackInt = @import("int.zig").unpackInt;
pub const unpackMap = @import("map.zig").unpackMap;
pub const unpackNil = @import("nil.zig").unpackNil;
pub const unpackStr = @import("str.zig").unpackStr;

const ext = @import("ext.zig");
pub const Ext = ext.Ext;
pub const packExt = ext.packExt;
pub const Timestamp = ext.Timestamp;
pub const packTimestamp = ext.packTimestamp;

pub const format = @import("format.zig");

pub const PackError = @import("error.zig").PackError;

pub const PackOptions = @import("pack.zig").PackOptions;
pub const packWithOptions = @import("pack.zig").packWithOptions;
pub const pack = @import("pack.zig").pack;

pub const UnpackError = @import("error.zig").UnpackError;
pub const unpack = @import("unpack.zig").unpack;

const std = @import("std");
pub fn Stream(comptime Container: type) type {
    return struct {
        const Self = @This();
        container: *Container,
        allocator: std.mem.Allocator,

        pub fn init(container: *Container, allocator: std.mem.Allocator) Self {
            return .{ .container = container, .allocator = allocator };
        }

        pub fn mzgUnpack(self: Self, buffer: []const u8) UnpackError!usize {
            var size: usize = 0;

            while (size < buffer.len) {
                size += unpack(
                    buffer[size..],
                    try self.container.addOne(self.allocator),
                ) catch {
                    _ = self.container.pop();
                    return size;
                };
            }
            return size;
        }
    };
}
pub fn stream(out: anytype, allocator: std.mem.Allocator) Stream(std.meta.Child(@TypeOf(out))) {
    return .init(out, allocator);
}

pub fn Array(comptime Container: type) type {
    return struct {
        const Self = @This();
        container: *Container,
        allocator: std.mem.Allocator,

        pub fn init(container: *Container, allocator: std.mem.Allocator) Self {
            return .{ .container = container, .allocator = allocator };
        }

        pub fn mzgUnpack(self: Self, buffer: []const u8) UnpackError!usize {
            var len: usize = undefined;
            var size: usize = try unpack(buffer, &len);

            for (0..len) |_| {
                size += unpack(
                    buffer[size..],
                    try self.container.addOne(self.allocator),
                ) catch |err| {
                    _ = self.container.pop();
                    return err;
                };
            }
            return size;
        }
    };
}
pub fn array(out: anytype, allocator: std.mem.Allocator) Array(std.meta.Child(@TypeOf(out))) {
    return .init(out, allocator);
}
