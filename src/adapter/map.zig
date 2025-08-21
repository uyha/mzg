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
            writer: *Writer,
        ) PackError!void {
            const Container = StripPointer(Source);
            if (comptime hasFn(Container, "count") and hasFn(Container, "iterator")) {
                try mzg.packMap(self.source.count(), writer);
                var iterator = self.source.iterator();
                while (iterator.next()) |*kv| {
                    try mzg.packAdaptedWithOptions(kv.key_ptr, options, map, writer);
                    try mzg.packAdaptedWithOptions(kv.value_ptr, options, map, writer);
                }
            } else if (comptime hasFn(Container, "keys") and hasFn(Container, "values")) {
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
pub fn MapUnpacker(comptime Out: type) type {
    return struct {
        const Self = @This();

        out: *Out,
        behavior: DuplicateFieldBehavior,

        pub fn mzgUnpackAllocate(
            self: Self,
            allocator: Allocator,
            comptime map: anytype,
            buffer: []const u8,
        ) UnpackAllocateError!usize {
            var len: u32 = undefined;
            var size: usize = try mzg.unpackMap(buffer, &len);

            self.out.* = .empty;

            var key: @FieldType(Out.KV, "key") = undefined;
            var value: @FieldType(Out.KV, "value") = undefined;
            for (0..len) |_| {
                size += mzg.unpackAdaptedAllocate(
                    allocator,
                    map,
                    buffer[size..],
                    &key,
                ) catch |err| {
                    return err;
                };
                const result = try self.out.getOrPut(allocator, key);
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

                size += mzg.unpackAdaptedAllocate(
                    allocator,
                    map,
                    buffer[size..],
                    target,
                ) catch |err| {
                    if (hasFn(Out, "pop")) {
                        _ = self.out.pop();
                    } else if (hasFn(Out, "remove")) {
                        _ = self.out.remove(key);
                    }
                    return err;
                };
            }
            return size;
        }
    };
}

pub fn unpackMap(out: anytype) MapUnpacker(StripPointer(@TypeOf(out))) {
    return .{ .out = out, .behavior = .@"error" };
}
pub fn unpackMapFirst(out: anytype) MapUnpacker(StripPointer(@TypeOf(out))) {
    return .{ .out = out, .behavior = .use_first };
}
pub fn unpackMapLast(out: anytype) MapUnpacker(StripPointer(@TypeOf(out))) {
    return .{ .out = out, .behavior = .use_last };
}

pub fn StaticStringMapUnpacker(comptime Out: type) type {
    return struct {
        const Self = @This();

        out: *Out,

        pub fn mzgUnpackAllocate(
            self: Self,
            allocator: Allocator,
            comptime map: anytype,
            buffer: []const u8,
        ) mzg.UnpackAllocateError!usize {
            const Key = @FieldType(Out.KV, "key");
            const Value = @FieldType(Out.KV, "value");
            const KV = struct { Key, Value };

            var len: usize = undefined;
            var consumed = try mzg.unpackMap(buffer, &len);

            var kvs = try allocator.alloc(KV, len);
            defer allocator.free(kvs);

            for (0..len) |i| {
                consumed += try mzg.unpackAdaptedAllocate(
                    allocator,
                    map,
                    buffer[consumed..],
                    &kvs[i][0],
                );
                consumed += try mzg.unpackAdaptedAllocate(
                    allocator,
                    map,
                    buffer[consumed..],
                    &kvs[i][1],
                );
            }

            self.out.* = try .init(kvs, allocator);

            return consumed;
        }
    };
}

pub fn unpackStaticStringMap(out: anytype) StaticStringMapUnpacker(StripPointer(@TypeOf(out))) {
    return .{ .out = out };
}

const std = @import("std");
const hasFn = std.meta.hasFn;
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;

const mzg = @import("root.zig").mzg;
const UnpackError = mzg.UnpackError;
const UnpackAllocateError = mzg.UnpackAllocateError;
const PackError = mzg.PackError;
const PackOptions = mzg.PackOptions;
const StripPointer = @import("../utils.zig").StripPointer;
