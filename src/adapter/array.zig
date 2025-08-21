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
            writer: *Writer,
        ) PackError!void {
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
        out: *Container,

        pub fn mzgUnpackAllocate(
            self: Self,
            allocator: Allocator,
            comptime map: anytype,
            buffer: []const u8,
        ) UnpackAllocateError!usize {
            var len: u32 = undefined;
            var size: usize = try mzg.unpackArray(buffer, &len);

            self.out.* = .empty;

            for (0..len) |_| {
                size += mzg.unpackAdaptedAllocate(
                    allocator,
                    map,
                    buffer[size..],
                    try self.out.addOne(allocator),
                ) catch |err| {
                    _ = self.out.pop();
                    return err;
                };
            }
            return size;
        }
    };
}

pub fn unpackArray(out: anytype) ArrayUnpacker(StripPointer(@TypeOf(out))) {
    return .{ .out = out };
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;

const mzg = @import("root.zig").mzg;
const UnpackError = mzg.UnpackError;
const UnpackAllocateError = mzg.UnpackAllocateError;
const PackError = mzg.PackError;
const PackOptions = mzg.PackOptions;
const StripPointer = @import("../utils.zig").StripPointer;
