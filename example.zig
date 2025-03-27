pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    const allocator = debug_allocator.allocator();
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    try mzg.pack(
        union(enum) { a: u16, b: u32 }{ .b = 1 },
        buffer.writer(allocator),
    );

    std.debug.print("{X:02}\n", .{buffer.items});
}

const std = @import("std");
const mzg = @import("mzg");
