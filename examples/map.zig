pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    std.debug.print("Map un/packing\n", .{});

    var prison: std.StringHashMapUnmanaged([]const u8) = .empty;
    defer prison.deinit(allocator);
    try prison.put(allocator, "1", "42");
    try prison.put(allocator, "42", "53");
    try prison.put(allocator, "53", "1");
    try mzg.pack(adapter.packMap(&prison), buffer.writer(allocator));

    var targets: std.StringArrayHashMapUnmanaged([]const u8) = .empty;
    defer targets.deinit(allocator);
    const size = try mzg.unpackAllocate(
        allocator,
        buffer.items,
        adapter.unpackMap(&targets),
    );
    std.debug.print("Consumed {} bytes\n", .{size});
    var iterator = targets.iterator();
    while (iterator.next()) |*t| {
        std.debug.print("{s}: {s}\n", .{ t.key_ptr.*, t.value_ptr.* });
    }
}

const std = @import("std");
const mzg = @import("mzg");
const adapter = mzg.adapter;
