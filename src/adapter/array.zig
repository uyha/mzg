const std = @import("std");
const mzg = @import("root.zig").mzg;
const UnpackError = mzg.UnpackError;
const PackError = mzg.PackError;
const PackOptions = mzg.PackOptions;

pub fn ArrayPacker(comptime Container: type) type {
    return struct {
        const Self = @This();
        container: *Container,

        pub fn init(container: *Container) Self {
            return .{ .container = container };
        }

        pub fn mzgPack(
            self: Self,
            options: PackOptions,
            writer: anytype,
        ) PackError(@TypeOf(writer))!void {
            try mzg.packWithOptions(self.container.items.len, options, writer);
            for (self.container.items) |*item| {
                try mzg.packWithOptions(item, options, writer);
            }
        }
    };
}
pub fn packArray(in: anytype) ArrayPacker(std.meta.Child(@TypeOf(in))) {
    return .init(in);
}

pub fn ArrayUnpacker(comptime Container: type) type {
    return struct {
        const Self = @This();
        container: *Container,
        allocator: std.mem.Allocator,

        pub fn init(container: *Container, allocator: std.mem.Allocator) Self {
            return .{ .container = container, .allocator = allocator };
        }

        pub fn mzgUnpack(self: Self, buffer: []const u8) UnpackError!usize {
            var len: u32 = undefined;
            var size: usize = try mzg.unpack(buffer, &len);

            for (0..len) |_| {
                size += mzg.unpack(
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

pub fn unpackArray(
    out: anytype,
    allocator: std.mem.Allocator,
) ArrayUnpacker(std.meta.Child(@TypeOf(out))) {
    return .init(out, allocator);
}
