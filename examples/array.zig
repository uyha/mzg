pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var allocWriter: Writer.Allocating = .init(allocator);
    defer allocWriter.deinit();
    const writer: *Writer = &allocWriter.writer;

    var in: std.ArrayList(u32) = .empty;
    defer in.deinit(allocator);
    try in.append(allocator, 42);
    try in.append(allocator, 75);
    try mzg.pack(adapter.packArray(&in), writer);

    var out: std.ArrayList(u32) = .empty;
    defer out.deinit(allocator);
    const size = try mzg.unpackAllocate(
        allocator,
        writer.buffer[0..writer.end],
        adapter.unpackArray(&out),
    );
    std.debug.print("Consumed {} bytes\n", .{size});
    std.debug.print("out: {any}\n", .{out.items});
}

const std = @import("std");
const Writer = std.Io.Writer;

const mzg = @import("mzg");
const adapter = mzg.adapter;
