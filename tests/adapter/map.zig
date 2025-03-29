const std = @import("std");
const t = std.testing;
const mzg = @import("mzg");
const adapter = mzg.adapter;

test "pack and unpack with map adapter" {
    const allocator = t.allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    var in: std.StringArrayHashMapUnmanaged([]const u8) = .empty;
    defer in.deinit(allocator);
    try in.put(allocator, "1", "42");
    try in.put(allocator, "42", "53");
    try in.put(allocator, "53", "1");
    try mzg.pack(adapter.packMap(&in), buffer.writer(allocator));

    var out: std.StringArrayHashMapUnmanaged([]const u8) = .empty;
    _ = try mzg.unpack(
        buffer.items,
        adapter.unpackMap(&out, .use_first, allocator),
    );
    defer out.deinit(allocator);

    var iter = in.iterator();
    while (iter.next()) |kv| {
        try t.expectEqualDeep(kv.value_ptr.*, out.get(kv.key_ptr.*).?);
    }
}
