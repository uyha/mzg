const std = @import("std");
const builtin = @import("builtin");
const t = std.testing;

const Behavior = struct {
    /// The endianess of the input
    endian: std.builtin.Endian = builtin.target.cpu.arch.endian(),
};

pub fn packNil(
    writer: anytype,
) @TypeOf(writer).Error!void {
    try writer.writeByte(0xC0);
}
pub fn packBool(
    writer: anytype,
    value: bool,
) @TypeOf(writer).Error!void {
    try writer.writeByte(if (value) 0xC3 else 0xC2);
}

// Originally, the `behavior` parameter contains a `priority` field that specifies if
// the packing procedure should prioritize for the smallest amount of byte written, or
// skipping the value checks and just write the bytes according to the type of input.
// This was done with the assumption that skipping the checks can have some performance
// gain. However, with some basic benchmarking, skipping the checks hinders the
// performance when the act of writing the bytes is more costly than the checks (almost
// always is). Even when the cost of the writing is 0 (a null writer), no statistically
// significance is found between the `.size` and `.speed` priority. Hence, the
// optimization for size is chosen to be always the behavior.
pub fn packIntWithBehavior(
    comptime behavior: Behavior,
    writer: anytype,
    input: anytype,
) @TypeOf(writer).Error!void {
    const Input = @TypeOf(input);

    if (comptime Input == comptime_int) {
        return packIntWithBehavior(behavior, writer, @as(RuntimeInt(input), input));
    }

    if (0 <= input) {
        if (input <= std.math.maxInt(u7)) {
            return try writer.writeByte(@intCast(input));
        }
        inline for (.{ u8, u16, u32, u64 }) |T| {
            if (input <= std.math.maxInt(T)) {
                const converted: T = @intCast(input);
                try writer.writeByte(marker(T));
                try writeWithEndian(
                    behavior.endian,
                    writer,
                    @ptrCast(&converted),
                    @sizeOf(T),
                );
                return;
            }
        }
    } else {
        if (-32 <= input) {
            return try writer.writeByte(@bitCast(input));
        }
        inline for (.{ i8, i16, i32, i64 }) |T| {
            if (std.math.minInt(T) <= input) {
                const converted: T = @intCast(input);
                try writer.writeByte(marker(T));
                try writeWithEndian(
                    behavior.endian,
                    writer,
                    @ptrCast(&converted),
                    @sizeOf(T),
                );
                return;
            }
        }
    }

    try writer.writeByte(marker(Input));
    try writeWithEndian(behavior.endian, writer, @ptrCast(&input), @sizeOf(Input));
}

pub fn packInt(
    writer: anytype,
    input: anytype,
) @TypeOf(writer).Error!void {
    return packIntWithBehavior(.{
        .endian = builtin.target.cpu.arch.endian(),
    }, writer, input);
}

fn RuntimeInt(input: comptime_int) type {
    if (input >= 0) {
        inline for (.{ u8, u16, u32, u64 }) |T| {
            if (input <= std.math.maxInt(T)) {
                return T;
            }
        }
    } else {
        inline for (.{ i8, i16, i32, i64 }) |T| {
            if (std.math.minInt(T) <= input) {
                return T;
            }
        }
    }
}
inline fn writeWithEndian(
    comptime endian: std.builtin.Endian,
    writer: anytype,
    ptr: [*]const u8,
    len: usize,
) @TypeOf(writer).Error!void {
    switch (endian) {
        .big => {
            for (0..len) |i| {
                try writer.writeByte(ptr[i]);
            }
        },
        .little => {
            for (0..len) |i| {
                try writer.writeByte(ptr[len - 1 - i]);
            }
        },
    }
}
fn marker(comptime T: type) u8 {
    if (comptime @sizeOf(usize) > @sizeOf(u64)) {
        @compileError("usize is too large and cannot be packed as an int");
    }

    return switch (comptime T) {
        u8 => 0xCC,
        u16 => 0xCD,
        u32 => 0xCE,
        usize, u64 => 0xCF,
        i8 => 0xD0,
        i16 => 0xD1,
        i32 => 0xD2,
        i64 => 0xD3,
        else => @compileError(@typeName(T) ++ " cannot be pack as an int"),
    };
}

test "pack" {
    const maxInt = std.math.maxInt;

    const expect = struct {
        fn expect(
            packer: anytype,
            input: anytype,
            output: []const u8,
        ) !void {
            var buffer: std.ArrayListUnmanaged(u8) = .empty;
            defer buffer.deinit(t.allocator);

            const packer_info = @typeInfo(@TypeOf(packer)).@"fn";

            switch (packer_info.params.len) {
                1 => try @call(.auto, packer, .{
                    buffer.writer(t.allocator),
                }),
                2 => try @call(.auto, packer, .{
                    buffer.writer(t.allocator),
                    input,
                }),
                3 => try @call(
                    .auto,
                    packer,
                    .{
                        comptime Behavior{
                            .endian = builtin.target.cpu.arch.endian(),
                        },
                        buffer.writer(t.allocator),
                        input,
                    },
                ),
                else => @compileError("WTF"),
            }

            const result = t.expect(std.mem.eql(u8, buffer.items, output));

            if (result) {} else |err| {
                if (@typeInfo(@TypeOf(input)) == .int) {
                    std.debug.print(
                        " {X:02} != {X:02}\n",
                        .{ output, buffer.items },
                    );
                }
                return err;
            }
        }
    }.expect;

    try expect(packNil, {}, &[_]u8{0xC0});
    try expect(packBool, false, &[_]u8{0xC2});
    try expect(packBool, true, &[_]u8{0xC3});

    const pInt = packIntWithBehavior;

    // u8
    try expect(pInt, @as(u8, 0), &[_]u8{0x00});
    try expect(pInt, @as(u8, 126), &[_]u8{0x7E});
    try expect(pInt, @as(u8, 127), &[_]u8{0x7F});
    try expect(pInt, @as(u8, 128), &[_]u8{ 0xCC, 0x80 });
    try expect(pInt, @as(u8, 255), &[_]u8{ 0xCC, 0xFF });

    // u16
    try expect(pInt, @as(u16, 0), &[_]u8{0x00});
    try expect(pInt, @as(u16, maxInt(u8)), &[_]u8{ 0xCC, 0xFF });
    try expect(pInt, @as(u16, maxInt(u8) + 1), &[_]u8{ 0xCD, 0x01, 0x00 });
    try expect(pInt, @as(u16, maxInt(u16)), &[_]u8{ 0xCD, 0xFF, 0xFF });

    // u32
    try expect(pInt, @as(u32, 0), &[_]u8{0x00});
    try expect(pInt, @as(u32, maxInt(u8)), &[_]u8{ 0xCC, 0xFF });
    try expect(pInt, @as(u32, maxInt(u16)), &[_]u8{ 0xCD, 0xFF, 0xFF });
    try expect(pInt, @as(u32, maxInt(u16) + 1), &[_]u8{ 0xCE, 0x00, 0x01, 0x00, 0x00 });
    try expect(pInt, @as(u32, maxInt(u32)), &[_]u8{ 0xCE, 0xFF, 0xFF, 0xFF, 0xFF });

    // u64
    try expect(pInt, @as(u64, 0), &[_]u8{0x00});
    try expect(pInt, @as(u64, maxInt(u8)), &[_]u8{ 0xCC, 0xFF });
    try expect(pInt, @as(u64, maxInt(u16)), &[_]u8{ 0xCD, 0xFF, 0xFF });
    try expect(pInt, @as(u64, maxInt(u16) + 1), &[_]u8{ 0xCE, 0x00, 0x01, 0x00, 0x00 });
    try expect(pInt, @as(u64, maxInt(u32)), &[_]u8{ 0xCE, 0xFF, 0xFF, 0xFF, 0xFF });
    try expect(
        pInt,
        @as(u64, maxInt(u32) + 1),
        &[_]u8{ 0xCF, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00 },
    );
    try expect(
        pInt,
        @as(u64, maxInt(u64)),
        &[_]u8{ 0xCF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    );

    try expect(pInt, @as(i8, 0), &[_]u8{0x00});
    try expect(pInt, @as(i8, -1), &[_]u8{0xFF});
    try expect(pInt, @as(i8, -32), &[_]u8{0xE0});
    try expect(pInt, @as(i8, -32), &[_]u8{0xE0});
    try expect(pInt, @as(i8, 127), &[_]u8{0x7F});
    try expect(pInt, @as(i8, -128), &[_]u8{ 0xD0, 0x80 });
}
