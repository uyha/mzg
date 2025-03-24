pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    const allocator = debug_allocator.allocator();
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    const packer = zmgp.packerWithBehavior(.{
        .@"struct" = .map,
        .skip_null = true,
    }, buffer.writer(allocator));

    const S = struct {
        @"1": ?u16 = null,
        b: struct {
            @"1": u16 = 1,
        } = .{},
    };
    try packer.pack(S{});

    std.debug.print("{X:02}\n", .{buffer.items});
}

const std = @import("std");
const zmgp = @import("zmgp");
