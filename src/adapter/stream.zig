pub fn StreamPacker(comptime Source: type) type {
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
            for (self.source.items) |*item| {
                try mzg.packAdaptedWithOptions(item, options, map, writer);
            }
        }
    };
}
pub fn packStream(in: anytype) StreamPacker(@TypeOf(in)) {
    return .init(in);
}

pub fn StreamUnpacker(comptime Out: type) type {
    return struct {
        const Self = @This();
        out: *Out,

        pub fn mzgUnpackAllocate(
            self: Self,
            allocator: Allocator,
            comptime map: anytype,
            buffer: []const u8,
        ) UnpackAllocateError!usize {
            var size: usize = 0;

            self.out.* = .empty;

            while (size < buffer.len) {
                size += mzg.unpackAdaptedAllocate(
                    allocator,
                    map,
                    buffer[size..],
                    try self.out.addOne(allocator),
                ) catch {
                    _ = self.out.pop();
                    return size;
                };
            }
            return size;
        }
    };
}

pub fn unpackStream(out: anytype) StreamUnpacker(StripPointer(@TypeOf(out))) {
    return .{ .out = out };
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;

const mzg = @import("root.zig").mzg;
const UnpackAllocateError = mzg.UnpackAllocateError;
const PackError = mzg.PackError;
const PackOptions = mzg.PackOptions;
const StripPointer = @import("../utils.zig").StripPointer;
