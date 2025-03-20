const std = @import("std");

const zimp = @import("root.zig");

pub fn main() !void {
    const size = 1_000_000;

    var arg_iter = std.process.args();
    _ = arg_iter.next();

    const priority_arg = arg_iter.next().?;
    const priority: zimp.Priority = if (std.mem.eql(u8, priority_arg, "size"))
        .size
    else
        .speed;

    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);
    try buffer.ensureTotalCapacity(allocator, size * (8 + 1));

    var timer = try std.time.Timer.start();
    const start = timer.lap();

    switch (priority) {
        .size => {
            for (0..size) |_| {
                try zimp.packIntWithBehavior(
                    .{ .priority = .size },
                    buffer.writer(allocator),
                    std.math.maxInt(u64),
                );
            }
        },
        .speed => {
            for (0..size) |_| {
                try zimp.packIntWithBehavior(
                    .{ .priority = .speed },
                    buffer.writer(allocator),
                    std.math.maxInt(u64),
                );
            }
        },
    }

    const end = timer.read();

    const elapsed_ms = @as(f64, @floatFromInt(end - start)) / std.time.ns_per_ms;
    std.debug.print("{}\n", .{elapsed_ms});
}
