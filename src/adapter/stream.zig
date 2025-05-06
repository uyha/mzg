const std = @import("std");
const mzg = @import("root.zig").mzg;
const UnpackError = mzg.UnpackError;
const PackError = mzg.PackError;
const PackOptions = mzg.PackOptions;

pub fn StreamPacker(comptime Container: type) type {
    return struct {
        const Self = @This();
        container: *const Container,

        pub fn init(container: *const Container) Self {
            return .{ .container = container };
        }

        pub fn mzgPack(
            self: Self,
            options: PackOptions,
            writer: anytype,
        ) PackError(@TypeOf(writer))!void {
            for (self.container.items) |*item| {
                try mzg.packWithOptions(item, options, writer);
            }
        }
    };
}
pub fn packStream(in: anytype) StreamPacker(std.meta.Child(@TypeOf(in))) {
    return .init(in);
}

pub fn StreamUnpacker(comptime Container: type) type {
    return struct {
        const Self = @This();
        container: *Container,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, container: *Container) Self {
            return .{ .container = container, .allocator = allocator };
        }

        pub fn mzgUnpack(self: Self, buffer: []const u8) UnpackError!usize {
            var size: usize = 0;

            while (size < buffer.len) {
                size += mzg.unpack(
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

pub fn unpackStream(
    allocator: std.mem.Allocator,
    out: anytype,
) StreamUnpacker(std.meta.Child(@TypeOf(out))) {
    return .init(allocator, out);
}
