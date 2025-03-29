const std = @import("std");
const t = std.testing;
const mzg = @import("mzg");
const adapter = mzg.adapter;

test "pack and unpack with array adapter" {
    const allocator = t.allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(t.allocator);

    var in: std.ArrayListUnmanaged(u32) = .empty;
    defer in.deinit(allocator);
    try in.append(allocator, 42);
    try in.append(allocator, 75);
    try mzg.pack(adapter.packArray(&in), buffer.writer(allocator));

    var out: std.ArrayListUnmanaged(u32) = .empty;
    defer out.deinit(allocator);
    _ = try mzg.unpack(
        buffer.items,
        adapter.unpackArray(&out, allocator),
    );

    try t.expectEqualDeep(in, out);
}
