pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var allocWriter: Writer.Allocating = .init(allocator);
    defer allocWriter.deinit();
    const writer: *Writer = &allocWriter.writer;

    std.debug.print("Map un/packing\n", .{});

    var prison: std.StringHashMapUnmanaged([]const u8) = .empty;
    defer prison.deinit(allocator);
    try prison.put(allocator, "1", "42");
    try prison.put(allocator, "42", "53");
    try prison.put(allocator, "53", "1");
    try mzg.pack(adapter.packMap(&prison), writer);

    var targets: std.StringArrayHashMapUnmanaged([]const u8) = .empty;
    defer targets.deinit(allocator);
    const size = try mzg.unpackAllocate(
        allocator,
        writer.buffer[0..writer.end],
        adapter.unpackMap(&targets),
    );
    std.debug.print("Consumed {} bytes\n", .{size});
    var iterator = targets.iterator();
    while (iterator.next()) |*t| {
        std.debug.print("{s}: {s}\n", .{ t.key_ptr.*, t.value_ptr.* });
    }
}

const std = @import("std");
const Writer = std.Io.Writer;

const mzg = @import("mzg");
const adapter = mzg.adapter;
