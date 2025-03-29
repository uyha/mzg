const std = @import("std");
const t = std.testing;
const mzg = @import("mzg");
const adapter = mzg.adapter;

const Position = enum(i32) {
    _,
    pub fn init(raw: std.meta.Tag(@This())) @This() {
        return @enumFromInt(raw);
    }
};
const Velocity = enum(i32) {
    _,
    pub fn init(raw: std.meta.Tag(@This())) @This() {
        return @enumFromInt(raw);
    }
};
const Targets = struct {
    position: Position,
    velocity: Velocity,
};

test "pack and unpack with stream adapter" {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    var in: std.ArrayListUnmanaged(Targets) = .empty;
    defer in.deinit(allocator);
    try in.append(allocator, .{ .position = .init(1000), .velocity = .init(50) });
    try in.append(allocator, .{ .position = .init(2000), .velocity = .init(10) });
    try mzg.pack(adapter.packStream(&in), buffer.writer(allocator));

    var out: std.ArrayListUnmanaged(Targets) = .empty;
    defer out.deinit(allocator);
    _ = try mzg.unpack(
        buffer.items,
        adapter.unpackStream(&out, allocator),
    );

    try t.expectEqualDeep(in, out);
}
