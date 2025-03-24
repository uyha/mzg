const builtin = @import("builtin");
const std = @import("std");

pub fn expect(
    packer: anytype,
    expected: anytype,
    input: anytype,
) !void {
    const Input = @TypeOf(input);
    const Expected = @TypeOf(expected);

    const t = std.testing;

    var output: std.ArrayListUnmanaged(u8) = .empty;
    defer output.deinit(t.allocator);

    const packer_info = @typeInfo(@TypeOf(packer)).@"fn";

    const returned = switch (packer_info.params.len) {
        1 => @call(.auto, packer, .{output.writer(t.allocator)}),
        2 => @call(.auto, packer, .{ output.writer(t.allocator), input }),
        else => @compileError("WTF"),
    };

    const result = switch (@typeInfo(Expected)) {
        .error_set => t.expectEqualDeep(expected, returned),
        else => t.expectEqualDeep(expected, output.items),
    };

    if (result) {} else |err| {
        switch (@typeInfo(Expected)) {
            .pointer => {
                if (Input != []const u8) {
                    std.debug.print("input {any}\n", .{input});
                }
                const diff_index = std.mem.indexOfDiff(u8, expected, output.items).?;
                std.debug.print("expected: {X:02}\n", .{expected});
                std.debug.print("ouput:    {X:02}\n", .{output.items});
                std.debug.print(
                    "expected[{0:}]: {1X:02} != output[{0:}]: {2X:02}\n",
                    .{ diff_index, expected[diff_index], output.items[diff_index] },
                );
            },
            else => {
                std.debug.print("expected: {any}\n", .{expected});
                std.debug.print("ouput: {any}\n", .{output.items});
            },
        }
        return err;
    }
}
