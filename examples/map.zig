pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    std.debug.print("Map un/packing\n", .{});

    var prison: std.StringArrayHashMapUnmanaged([]const u8) = .empty;
    try prison.put(allocator, "1", "42");
    try prison.put(allocator, "42", "53");
    try prison.put(allocator, "53", "1");
    try mzg.pack(adapter.packMap(&prison), buffer.writer(allocator));

    // Inject stray byte
    try buffer.append(allocator, 1);

    std.debug.print("MessagPack bytes: {X:02}\n", .{buffer.items});

    var targets: std.StringArrayHashMapUnmanaged([]const u8) = .empty;
    std.debug.print("Consumed {} bytes\n", .{try mzg.unpack(
        buffer.items,
        adapter.unpackMap(&targets, .use_first, allocator),
    )});
    std.debug.print("Length: {}\n", .{targets.count()});
    var iterator = targets.iterator();
    while (iterator.next()) |*t| {
        std.debug.print("{s}: {s}\n", .{ t.key_ptr.*, t.value_ptr.* });
    }
}

const std = @import("std");
const mzg = @import("mzg");
const adapter = mzg.adapter;
