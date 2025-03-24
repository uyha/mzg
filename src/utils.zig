const builtin = @import("builtin");
const std = @import("std");

pub fn NativeUsize() type {
    return switch (@sizeOf(usize)) {
        @sizeOf(u32) => u32,
        @sizeOf(u64) => u64,
        else => @compileError(
            "usize is only support if it is the same size with either u32 or u64",
        ),
    };
}

pub inline fn writeWithEndian(
    comptime endian: std.builtin.Endian,
    writer: anytype,
    input: anytype,
) @TypeOf(writer).Error!void {
    const Input = @TypeOf(input);
    const raw = raw: switch (Input) {
        f32, f64 => |Float| {
            const Target = if (Float == f32) u32 else u64;
            if (comptime endian == .little) {
                break :raw @byteSwap(@as(Target, @bitCast(input)));
            } else {
                break :raw @as(Target, @bitCast(input));
            }
        },
        u8, u16, u32, u64, i8, i16, i32, i64 => if (comptime endian == .little)
            @byteSwap(input)
        else
            input,
        usize => if (comptime endian == .little)
            @byteSwap(@as(NativeUsize(), input))
        else
            @as(NativeUsize(), input),
        else => @compileError(std.fmt.comptimePrint(
            "{s} is not supported by this function",
            .{@typeName(Input)},
        )),
    };

    try writer.writeAll(std.mem.asBytes(&raw));
}

pub fn expect(
    packer: anytype,
    input: anytype,
    expected: anytype,
) !void {
    const Input = @TypeOf(input);
    const Expected = @TypeOf(expected);

    const t = std.testing;

    var output: std.ArrayListUnmanaged(u8) = .empty;
    defer output.deinit(t.allocator);

    const packer_info = @typeInfo(@TypeOf(packer)).@"fn";

    const returned = switch (packer_info.params.len) {
        1 => @call(.auto, packer, .{
            output.writer(t.allocator),
        }),
        2 => @call(.auto, packer, .{
            output.writer(t.allocator),
            input,
        }),
        3 => @call(
            .auto,
            packer,
            .{
                comptime builtin.target.cpu.arch.endian(),
                output.writer(t.allocator),
                input,
            },
        ),
        else => @compileError("WTF"),
    };

    const result = switch (@typeInfo(Expected)) {
        .error_set => t.expectEqualDeep(expected, returned),
        else => t.expectEqualDeep(expected, output.items),
    };

    if (result) {} else |err| {
        if (Expected == []const u8) {
            const diff_index = std.mem.indexOfDiff(u8, expected, output.items).?;
            if (Input != []const u8) {
                std.debug.print("input {any}\n", .{input});
            }
            std.debug.print("difference at {any}\n", .{diff_index});
            std.debug.print("expected: {X:02}\n", .{expected});
            std.debug.print("ouput: {X:02}\n", .{output.items});
            std.debug.print(
                "expected: {X:02} != output: {X:02}\n",
                .{ expected[diff_index], output.items[diff_index] },
            );
        } else {
            std.debug.print("expected: {any}\n", .{expected});
            std.debug.print("ouput: {any}\n", .{output.items});
        }
        return err;
    }
}
