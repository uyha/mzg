test "pack and unpack with array adapter" {
    const allocator = t.allocator;

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
    _ = try mzg.unpackAllocate(
        allocator,
        writer.buffer[0..writer.end],
        adapter.unpackArray(&out),
    );

    try t.expectEqualDeep(in, out);
}

const std = @import("std");
const t = std.testing;
const Writer = std.Io.Writer;

const mzg = @import("mzg");
const adapter = mzg.adapter;
