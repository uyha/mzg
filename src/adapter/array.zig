const std = @import("std");
const mzg = @import("root.zig").mzg;
const UnpackError = mzg.UnpackError;
const PackError = mzg.PackError;
const PackOptions = mzg.PackOptions;
const StripPointer = @import("../utils.zig").StripPointer;

pub fn ArrayPacker(comptime Source: type) type {
    return struct {
        const Self = @This();
        source: Source,

        pub fn init(source: Source) Self {
            return .{ .source = source };
        }

        pub fn mzgPack(
            self: Self,
            options: PackOptions,
            comptime map: anytype,
            writer: anytype,
        ) PackError(@TypeOf(writer))!void {
            try mzg.packArray(self.source.items.len, writer);
            for (self.source.items) |*item| {
                try mzg.packAdaptedWithOptions(item, options, map, writer);
            }
        }
    };
}
pub fn packArray(in: anytype) ArrayPacker(@TypeOf(in)) {
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
            var size: usize = try mzg.unpackArray(buffer, &len);

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
    allocator: std.mem.Allocator,
    out: anytype,
) ArrayUnpacker(StripPointer(@TypeOf(out))) {
    return .init(out, allocator);
}
