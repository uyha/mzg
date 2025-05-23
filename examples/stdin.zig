pub fn main() !void {
    var buffer: [64]u8 = @splat(0);

    const size = try std.io.getStdIn().read(&buffer);

    var entry: Entry = undefined;

    _ = try mzg.unpack(buffer[0..size], &entry);

    std.debug.print(
        "{{name: \"{s}\", value: {}}}\n",
        .{ entry.name, entry.value },
    );
}

const std = @import("std");
const mzg = @import("mzg");

const Entry = struct {
    name: []const u8,
    value: u8,
};
