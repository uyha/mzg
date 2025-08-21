pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var allocWriter: Writer.Allocating = .init(allocator);
    defer allocWriter.deinit();
    const writer: *Writer = &allocWriter.writer;

    var in: std.ArrayList(Targets) = .empty;
    defer in.deinit(allocator);
    try in.append(allocator, .{ .position = .init(1000), .velocity = .init(50) });
    try in.append(allocator, .{ .position = .init(2000), .velocity = .init(10) });
    try mzg.pack(adapter.packStream(&in), writer);
    try mzg.pack(
        Targets{ .position = .init(3000), .velocity = .init(90) },
        writer,
    );

    var targets: std.ArrayList(Targets) = .empty;
    defer targets.deinit(allocator);
    const size = try mzg.unpackAllocate(
        allocator,
        writer.buffer[0..writer.end],
        adapter.unpackStream(&targets),
    );
    std.debug.print("Consumed {} bytes\n", .{size});
    for (targets.items) |*t| {
        std.debug.print("{}\n", .{t});
    }
}

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

const std = @import("std");
const Writer = std.Io.Writer;

const mzg = @import("mzg");
const adapter = mzg.adapter;
