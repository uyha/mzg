pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var allocWriter: Writer.Allocating = .init(allocator);
    defer allocWriter.deinit();
    const writer: *Writer = &allocWriter.writer;

    try mzg.pack(
        "a string with some characters for demonstration purpose",
        writer,
    );

    var string: []const u8 = undefined;
    const size = try mzg.unpack(writer.buffer[0..writer.end], &string);
    std.debug.print("Consumed {} bytes\n", .{size});
    std.debug.print("string: {s}\n", .{string});
}

const std = @import("std");
const Writer = std.Io.Writer;

const mzg = @import("mzg");
