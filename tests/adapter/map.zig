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
    defer out.deinit(allocator);
    _ = try mzg.unpackAllocate(
        allocator,
        buffer.items,
        adapter.unpackMap(&out),
    );

    var iter = in.iterator();
    while (iter.next()) |kv| {
        try t.expectEqualDeep(kv.value_ptr.*, out.get(kv.key_ptr.*).?);
    }
}

test "unpack with map adapter" {
    const allocator = t.allocator;

    const content = "\x81\xA3led\xABinproc://#2";

    var out: std.StringArrayHashMapUnmanaged([]const u8) = .empty;
    defer out.deinit(allocator);

    _ = try mzg.unpackAllocate(allocator, content, adapter.unpackMap(&out));

    try t.expectEqual(1, out.count());
    try t.expectEqualStrings("inproc://#2", out.get("led").?);
}

test "pack and unpack StaticStringMap with map adapter" {
    const allocator = t.allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    var in: std.StaticStringMap([]const u8) = .initComptime(&.{
        .{ "hello", "there" },
        .{ "general", "kenobi" },
    });
    try mzg.pack(adapter.packMap(&in), buffer.writer(allocator));

    var out: std.StaticStringMap([]const u8) = undefined;
    _ = try mzg.unpackAllocate(
        allocator,
        buffer.items,
        adapter.unpackStaticStringMap(&out),
    );
    defer out.deinit(allocator);

    for (in.keys(), in.values()) |key, value| {
        try t.expectEqualDeep(value, out.get(key).?);
    }
}
