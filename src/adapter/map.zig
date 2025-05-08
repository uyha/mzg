pub fn MapPacker(comptime Source: type) type {
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
            const Container = StripPointer(Source);
            if (comptime meta.hasFn(Container, "count") and meta.hasFn(Container, "iterator")) {
                try mzg.packMap(self.source.count(), writer);
                var iterator = self.source.iterator();
                while (iterator.next()) |*kv| {
                    try mzg.packAdaptedWithOptions(kv.key_ptr, options, map, writer);
                    try mzg.packAdaptedWithOptions(kv.value_ptr, options, map, writer);
                }
            } else if (comptime meta.hasFn(Container, "keys") and meta.hasFn(Container, "values")) {
                const keys = self.source.keys();
                const values = self.source.values();

                try mzg.packMap(keys.len, writer);

                for (keys, values) |key, value| {
                    try mzg.packAdaptedWithOptions(key, options, map, writer);
                    try mzg.packAdaptedWithOptions(value, options, map, writer);
                }
            } else {
                @compileError(@typeName(Source) ++ " is not supported");
            }
        }
    };
}
pub fn packMap(in: anytype) MapPacker(@TypeOf(in)) {
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
            allocator: std.mem.Allocator,
            container: *Container,
            behavior: DuplicateFieldBehavior,
        ) Self {
            return .{
                .container = container,
                .allocator = allocator,
                .behavior = behavior,
            };
        }

        pub fn mzgUnpack(self: Self, buffer: []const u8) UnpackError!usize {
            var len: u32 = undefined;
            var size: usize = try mzg.unpackMap(buffer, &len);

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
                    if (std.meta.hasFn(Container, "pop")) {
                        _ = self.container.pop();
                    } else if (std.meta.hasFn(Container, "remove")) {
                        _ = self.container.remove(key);
                    }
                    return err;
                };
            }
            return size;
        }
    };
}

pub fn unpackMap(
    allocator: std.mem.Allocator,
    out: anytype,
    behavior: DuplicateFieldBehavior,
) MapUnpacker(StripPointer(@TypeOf(out))) {
    return .init(allocator, out, behavior);
}

const std = @import("std");
const meta = std.meta;

const mzg = @import("root.zig").mzg;
const UnpackError = mzg.UnpackError;
const PackError = mzg.PackError;
const PackOptions = mzg.PackOptions;
const StripPointer = @import("../utils.zig").StripPointer;
