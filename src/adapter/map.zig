const std = @import("std");
const mzg = @import("root.zig").mzg;
const UnpackError = mzg.UnpackError;
const PackError = mzg.PackError;
const PackOptions = mzg.PackOptions;

pub fn MapPacker(comptime Container: type) type {
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
            try mzg.packMap(self.container.count(), writer);
            var iterator = self.container.iterator();
            while (iterator.next()) |*kv| {
                try mzg.packWithOptions(kv.key_ptr, options, writer);
                try mzg.packWithOptions(kv.value_ptr, options, writer);
            }
        }
    };
}
pub fn packMap(in: anytype) MapPacker(std.meta.Child(@TypeOf(in))) {
    return .init(in);
}

pub const DuplicateFieldBehavior = enum { use_first, @"error", use_last };
pub fn MapUnpacker(comptime Container: type) type {
    return struct {
        const Self = @This();
        container: *Container,
        allocator: std.mem.Allocator,

        behavior: DuplicateFieldBehavior,

        pub fn init(
            container: *Container,
            behavior: DuplicateFieldBehavior,
            allocator: std.mem.Allocator,
        ) Self {
            return .{
                .container = container,
                .allocator = allocator,
                .behavior = behavior,
            };
        }

        pub fn mzgUnpack(self: Self, buffer: []const u8) UnpackError!usize {
            var len: u32 = undefined;
            var size: usize = try mzg.unpack(buffer, &len);

            var key: @FieldType(Container.KV, "key") = undefined;
            var value: @FieldType(Container.KV, "value") = undefined;
            for (0..len) |_| {
                size += mzg.unpack(buffer[size..], &key) catch |err| {
                    return err;
                };
                const result = try self.container.getOrPut(self.allocator, key);
                const target = target: {
                    if (result.found_existing) {
                        switch (self.behavior) {
                            .use_first => break :target &value,
                            .@"error" => return UnpackError.ValueInvalid,
                            .use_last => break :target result.value_ptr,
                        }
                    } else {
                        break :target result.value_ptr;
                    }
                };

                size += mzg.unpack(buffer[size..], target) catch |err| {
                    _ = self.container.pop();
                    return err;
                };
            }
            return size;
        }
    };
}

pub fn unpackMap(
    out: anytype,
    behavior: DuplicateFieldBehavior,
    allocator: std.mem.Allocator,
) MapUnpacker(std.meta.Child(@TypeOf(out))) {
    return .init(out, behavior, allocator);
}
