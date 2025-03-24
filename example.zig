pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    const allocator = debug_allocator.allocator();
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    const packer = zmgp.packerWithBehavior(.{
        .@"enum" = .value,
        .skip_null = true,
    }, buffer.writer(allocator));

    try packer.pack(union(enum) { a: u16, b: u32 }{ .b = 1 });

    std.debug.print("{X:02}\n", .{buffer.items});
}

const std = @import("std");
const zmgp = @import("zmgp");
