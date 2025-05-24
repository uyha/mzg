pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    var in: std.ArrayListUnmanaged(u32) = .empty;
    defer in.deinit(allocator);
    try in.append(allocator, 42);
    try in.append(allocator, 75);
    try mzg.pack(adapter.packArray(&in), buffer.writer(allocator));

    var out: std.ArrayListUnmanaged(u32) = .empty;
    defer out.deinit(allocator);
    const size = try mzg.unpackAllocate(
        allocator,
        buffer.items,
        adapter.unpackArray(&out),
    );
    std.debug.print("Consumed {} bytes\n", .{size});
    std.debug.print("out: {any}\n", .{out.items});
}

const std = @import("std");
const mzg = @import("mzg");
const adapter = mzg.adapter;
