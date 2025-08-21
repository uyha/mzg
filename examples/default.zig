pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var allocWriter: Writer.Allocating = .init(allocator);
    defer allocWriter.deinit();
    const writer: *Writer = &allocWriter.writer;

    try mzg.pack(
        Targets{ .position = .init(2000), .velocity = .init(10) },
        writer,
    );

    var targets: Targets = undefined;
    const size = try mzg.unpack(writer.buffer[0..writer.end], &targets);

    std.debug.print("Consumed {} bytes\n", .{size});
    std.debug.print("Targets: {}\n", .{targets});
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
