pub fn expect(
    packer: anytype,
    expected: anytype,
    input: anytype,
) !void {
    const Input = @TypeOf(input);
    const Expected = @TypeOf(expected);

    const t = std.testing;

    var allocWriter: Writer.Allocating = .init(t.allocator);
    defer allocWriter.deinit();
    const writer: *Writer = &allocWriter.writer;

    const packer_info = @typeInfo(@TypeOf(packer)).@"fn";

    const returned = switch (packer_info.params.len) {
        1 => @call(.auto, packer, .{writer}),
        2 => @call(.auto, packer, .{ input, writer }),
        else => @compileError("WTF"),
    };

    const result = switch (@typeInfo(Expected)) {
        .error_set => t.expectEqualDeep(expected, returned),
        else => t.expectEqualDeep(expected, writer.buffer[0..writer.end]),
    };

    if (result) {} else |err| {
        const slice = writer.buffer[0..writer.end];
        switch (@typeInfo(Expected)) {
            .pointer => {
                if (Input != []const u8) {
                    std.debug.print("input {any}\n", .{input});
                }
                const diff_index = std.mem.indexOfDiff(u8, expected, slice).?;
                std.debug.print("expected: {X:02}\n", .{expected});
                std.debug.print("ouput:    {X:02}\n", .{slice});
                std.debug.print(
                    "expected[{0:}]: {1X:02} != output[{0:}]: {2X:02}\n",
                    .{ diff_index, expected[diff_index], writer.buffer[diff_index] },
                );
            },
            else => {
                std.debug.print("expected: {any}\n", .{expected});
                std.debug.print("ouput: {any}\n", .{slice});
            },
        }
        return err;
    }
}

const builtin = @import("builtin");

const std = @import("std");
const Writer = std.Io.Writer;
