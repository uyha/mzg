const std = @import("std");
const builtin = @import("builtin");

const maxInt = std.math.maxInt;

const target_endian = builtin.target.cpu.arch.endian();

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

// Originally, there was a `behavior` parameter that contains a `priority` field that
// specifies if the packing procedure should prioritize for the smallest amount of byte
// written, or skipping the value checks and just write the bytes according to the type
// of input. This was done with the assumption that skipping the checks can have some
// performance gain. However, with some basic benchmarking, skipping the checks hinders
// the performance when the act of writing the bytes is more costly than the checks
// (almost always is). Even when the cost of the writing is 0 (a null writer), no
// statistically significance is found between the `.size` and `.speed` priority. Hence,
// the optimization for size is chosen to always be the behavior.
pub fn packIntWithEndian(
    comptime endian: std.builtin.Endian,
    writer: anytype,
    input: anytype,
) @TypeOf(writer).Error!void {
    const Input = @TypeOf(input);

    comptime switch (@typeInfo(Input)) {
        .comptime_int => if (input < std.math.minInt(i64) or input > std.math.maxInt(u64)) {
            @compileError(std.fmt.comptimePrint(
                "cannot pack input outside of [-2^63, 2^64 -1], input is {}",
                .{input},
            ));
        },
        .int => |Int| if (Int.bits > 64) {
            @compileError(std.fmt.comptimePrint(
                "cannot pack input with more than 64 bits as an int, input has {} bits",
                .{Int.bits},
            ));
        },
        else => @compileError(@typeName(Input) ++ " cannot be packed as an int"),
    };

    if (-32 <= input and input <= std.math.maxInt(u7)) {
        return try writer.writeByte(@bitCast(@as(i8, @intCast(input))));
    }

    if (std.math.maxInt(u7) < input) {
        inline for (.{ u8, u16, u32, u64 }) |T| {
            if (input <= std.math.maxInt(T)) {
                try writer.writeByte(intMarker(T));
                try writeWithEndian(endian, writer, @as(T, @intCast(input)));
                return;
            }
        }
        unreachable;
    }

    inline for (.{ i8, i16, i32, i64 }) |T| {
        if (std.math.minInt(T) <= input) {
            try writer.writeByte(intMarker(T));
            try writeWithEndian(endian, writer, @as(T, @intCast(input)));
            return;
        }
    }
    unreachable;
}

pub fn packInt(
    writer: anytype,
    input: anytype,
) @TypeOf(writer).Error!void {
    return packIntWithEndian(target_endian, writer, input);
}

pub fn packFloatWithEndian(
    comptime endian: std.builtin.Endian,
    writer: anytype,
    input: anytype,
) @TypeOf(writer).Error!void {
    const Input = @TypeOf(input);

    comptime switch (@typeInfo(Input)) {
        .comptime_float => {
            // TODO: Not really sure how to check comptime_float if it fits f64, find a
            // way to check it later
        },
        .float => |Float| {
            if (Float.bits > 64) {
                @compileError(std.fmt.comptimePrint(
                    "cannot pack input with more than 64 bits as a float, input has {} bits",
                    .{Float.bits},
                ));
            }
        },
        else => @compileError(@typeName(Input) ++ " cannot be packed as a float"),
    };

    switch (comptime Input) {
        comptime_float => {
            try writer.writeByte(0xCB);
            try writeWithEndian(endian, writer, @as(f64, input));
        },
        f16 => {
            try writer.writeByte(0xCA);
            try writeWithEndian(endian, writer, @as(f32, input));
        },
        f32, f64 => {
            try writer.writeByte(if (Input == f32) 0xCA else 0xCB);
            try writeWithEndian(endian, writer, input);
        },
        else => unreachable,
    }
}
pub fn packFloat(writer: anytype, input: anytype) @TypeOf(writer).Error!void {
    return packFloatWithEndian(target_endian, writer, input);
}

pub fn PackStrError(WriterError: type) type {
    return WriterError || error{StringTooLong};
}
pub fn packStr(writer: anytype, input: []const u8) PackStrError(@TypeOf(writer).Error)!void {
    const Error = PackStrError(@TypeOf(writer).Error);
    switch (input.len) {
        0...31 => {
            try writer.writeByte(0b1010_0000 | @as(u8, @intCast(input.len)));
        },
        32...std.math.maxInt(u8) => |len| {
            try writer.writeAll(&[_]u8{ 0xD9, @as(u8, @intCast(len)) });
        },
        std.math.maxInt(u8) + 1...std.math.maxInt(u16) => |len| {
            try writer.writeByte(0xDA);
            try writeWithEndian(target_endian, writer, @as(u16, @intCast(len)));
        },
        std.math.maxInt(u16) + 1...std.math.maxInt(u32) => |len| {
            try writer.writeByte(0xDB);
            try writeWithEndian(target_endian, writer, @as(u32, @intCast(len)));
        },
        else => return Error.StringTooLong,
    }
    try writer.writeAll(input);
}
pub fn PackBinError(WriterError: type) type {
    return WriterError || error{BinaryTooLong};
}
pub fn packBin(writer: anytype, input: []const u8) PackBinError(@TypeOf(writer).Error)!void {
    const Error = PackBinError(@TypeOf(writer).Error);
    switch (input.len) {
        0...std.math.maxInt(u8) => |len| {
            try writer.writeAll(&[_]u8{ 0xC4, @as(u8, @intCast(len)) });
        },
        std.math.maxInt(u8) + 1...std.math.maxInt(u16) => |len| {
            try writer.writeByte(0xC5);
            try writeWithEndian(target_endian, writer, @as(u16, @intCast(len)));
        },
        std.math.maxInt(u16) + 1...std.math.maxInt(u32) => |len| {
            try writer.writeByte(0xC6);
            try writeWithEndian(target_endian, writer, @as(u32, @intCast(len)));
        },
        else => return Error.BinaryTooLong,
    }
    try writer.writeAll(input);
}
pub fn PackArrayError(WriterError: type) type {
    return WriterError || error{ArrayTooLong};
}
pub fn packArray(writer: anytype, size: usize) PackArrayError(@TypeOf(writer).Error)!void {
    const Error = PackArrayError(@TypeOf(writer).Error);
    switch (size) {
        0...15 => |len| try writer.writeByte(0b1001_0000 | @as(u8, @intCast(len))),
        16...maxInt(u16) => |len| {
            try writer.writeByte(0xDC);
            try writeWithEndian(target_endian, writer, @as(u16, @intCast(len)));
        },
        maxInt(u16) + 1...maxInt(u32) => |len| {
            try writer.writeByte(0xDD);
            try writeWithEndian(target_endian, writer, @as(u32, @intCast(len)));
        },
        else => return Error.ArrayTooLong,
    }
}

inline fn writeWithEndian(
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
fn NativeUsize() type {
    return switch (@sizeOf(usize)) {
        @sizeOf(u32) => u32,
        @sizeOf(u64) => u64,
        else => @compileError(
            "usize is only support if it is the same size with either u32 or u64",
        ),
    };
}
fn intMarker(comptime T: type) u8 {
    return switch (comptime T) {
        u8 => 0xCC,
        u16 => 0xCD,
        u32 => 0xCE,
        u64 => 0xCF,
        i8 => 0xD0,
        i16 => 0xD1,
        i32 => 0xD2,
        i64 => 0xD3,
        usize => intMarker(NativeUsize()),
        else => @compileError(@typeName(T) ++ " cannot be pack as an int"),
    };
}

fn expect(
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
        }
        return err;
    }
}

test "pack integrals" {
    const minInt = std.math.minInt;

    try expect(packNil, {}, &[_]u8{0xC0});
    try expect(packBool, false, &[_]u8{0xC2});
    try expect(packBool, true, &[_]u8{0xC3});

    const pInt = packIntWithEndian;

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
    try expect(pInt, @as(i8, maxInt(i8)), &[_]u8{0x7F});
    try expect(pInt, @as(i8, minInt(i8)), &[_]u8{ 0xD0, 0x80 });

    try expect(pInt, @as(i16, 0), &[_]u8{0x00});
    try expect(pInt, @as(i16, -1), &[_]u8{0xFF});
    try expect(pInt, @as(i16, -32), &[_]u8{0xE0});
    try expect(pInt, @as(i16, maxInt(i8)), &[_]u8{0x7F});
    try expect(pInt, @as(i16, minInt(i8)), &[_]u8{ 0xD0, 0x80 });
    try expect(pInt, @as(i16, maxInt(i8) + 1), &[_]u8{ 0xCC, 0x80 });
    try expect(pInt, @as(i16, minInt(i8) - 1), &[_]u8{ 0xD1, 0xFF, 0x7F });
    try expect(pInt, @as(i16, maxInt(i16)), &[_]u8{ 0xCD, 0x7F, 0xFF });
    try expect(pInt, @as(i16, minInt(i16)), &[_]u8{ 0xD1, 0x80, 0x00 });

    try expect(pInt, @as(i32, 0), &[_]u8{0x00});
    try expect(pInt, @as(i32, -1), &[_]u8{0xFF});
    try expect(pInt, @as(i32, -32), &[_]u8{0xE0});
    try expect(pInt, @as(i32, maxInt(i8)), &[_]u8{0x7F});
    try expect(pInt, @as(i32, minInt(i8)), &[_]u8{ 0xD0, 0x80 });
    try expect(pInt, @as(i32, maxInt(i8) + 1), &[_]u8{ 0xCC, 0x80 });
    try expect(pInt, @as(i32, minInt(i8) - 1), &[_]u8{ 0xD1, 0xFF, 0x7F });
    try expect(pInt, @as(i32, maxInt(i16)), &[_]u8{ 0xCD, 0x7F, 0xFF });
    try expect(pInt, @as(i32, minInt(i16)), &[_]u8{ 0xD1, 0x80, 0x00 });
    try expect(pInt, @as(i32, maxInt(i16) + 1), &[_]u8{ 0xCD, 0x80, 0x00 });
    try expect(pInt, @as(i32, minInt(i16) - 1), &[_]u8{ 0xD2, 0xFF, 0xFF, 0x7F, 0xFF });
    try expect(
        pInt,
        @as(i32, maxInt(i32)),
        &[_]u8{ 0xCE, 0x7F, 0xFF, 0xFF, 0xFF },
    );
    try expect(
        pInt,
        @as(i32, minInt(i32)),
        &[_]u8{ 0xD2, 0x80, 0x00, 0x00, 0x00 },
    );

    try expect(pInt, @as(i64, 0), &[_]u8{0x00});
    try expect(pInt, @as(i64, -1), &[_]u8{0xFF});
    try expect(pInt, @as(i64, -32), &[_]u8{0xE0});
    try expect(pInt, @as(i64, maxInt(i8)), &[_]u8{0x7F});
    try expect(pInt, @as(i64, minInt(i8)), &[_]u8{ 0xD0, 0x80 });
    try expect(pInt, @as(i64, maxInt(i8) + 1), &[_]u8{ 0xCC, 0x80 });
    try expect(pInt, @as(i64, minInt(i8) - 1), &[_]u8{ 0xD1, 0xFF, 0x7F });
    try expect(pInt, @as(i64, maxInt(i16)), &[_]u8{ 0xCD, 0x7F, 0xFF });
    try expect(pInt, @as(i64, minInt(i16)), &[_]u8{ 0xD1, 0x80, 0x00 });
    try expect(pInt, @as(i64, maxInt(i16) + 1), &[_]u8{ 0xCD, 0x80, 0x00 });
    try expect(pInt, @as(i64, minInt(i16) - 1), &[_]u8{ 0xD2, 0xFF, 0xFF, 0x7F, 0xFF });
    try expect(
        pInt,
        @as(i64, maxInt(i32)),
        &[_]u8{ 0xCE, 0x7F, 0xFF, 0xFF, 0xFF },
    );
    try expect(
        pInt,
        @as(i64, minInt(i32)),
        &[_]u8{ 0xD2, 0x80, 0x00, 0x00, 0x00 },
    );
    try expect(
        pInt,
        @as(i64, maxInt(i32) + 1),
        &[_]u8{ 0xCE, 0x80, 0x00, 0x00, 0x00 },
    );
    try expect(
        pInt,
        @as(i64, minInt(i32) - 1),
        &[_]u8{ 0xD3, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0xFF, 0xFF, 0xFF },
    );
    try expect(
        pInt,
        @as(i64, maxInt(i64)),
        &[_]u8{ 0xCF, 0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    );
    try expect(
        pInt,
        @as(i64, minInt(i64)),
        &[_]u8{ 0xD3, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
    );
}

test "pack floats" {
    try expect(
        packFloat,
        @as(f16, 1.0),
        &[_]u8{ 0xCA, 0x3F, 0x80, 0x00, 0x00 },
    );
    try expect(
        packFloat,
        @as(f32, 1.0),
        &[_]u8{ 0xCA, 0x3F, 0x80, 0x00, 0x00 },
    );
    try expect(
        packFloat,
        1.0,
        &[_]u8{ 0xCB, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
    );
    try expect(
        packFloat,
        @as(f64, 1.0),
        &[_]u8{ 0xCB, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
    );
}

test "pack str and bin" {
    // Cannot actually test for 2 ^ 32 long string or bin since the compilation just
    // freezes

    try expect(
        packStr,
        "1234",
        &[_]u8{ 0xA4, 0x31, 0x32, 0x33, 0x34 },
    );
    try expect(
        packStr,
        &[1]u8{0x31} ** std.math.maxInt(u8),
        &([_]u8{ 0xD9, 0xFF } ++ [1]u8{0x31} ** std.math.maxInt(u8)),
    );
    try expect(
        packStr,
        &[1]u8{0x31} ** std.math.maxInt(u16),
        &([_]u8{ 0xDA, 0xFF, 0xFF } ++ [1]u8{0x31} ** std.math.maxInt(u16)),
    );
    try expect(
        packStr,
        &[1]u8{0x31} ** (std.math.maxInt(u16) + 1),
        &([_]u8{ 0xDB, 0x00, 0x01, 0x00, 0x00 } ++ [1]u8{0x31} ** (std.math.maxInt(u16) + 1)),
    );

    try expect(
        packBin,
        "1234",
        &[_]u8{ 0xC4, 0x04, 0x31, 0x32, 0x33, 0x34 },
    );
    try expect(
        packBin,
        &[1]u8{0x31} ** std.math.maxInt(u8),
        &([_]u8{ 0xC4, 0xFF } ++ [1]u8{0x31} ** std.math.maxInt(u8)),
    );
    try expect(
        packBin,
        &[1]u8{0x31} ** std.math.maxInt(u16),
        &([_]u8{ 0xC5, 0xFF, 0xFF } ++ [1]u8{0x31} ** std.math.maxInt(u16)),
    );
    try expect(
        packBin,
        &[1]u8{0x31} ** (std.math.maxInt(u16) + 1),
        &([_]u8{ 0xC6, 0x00, 0x01, 0x00, 0x00 } ++ [1]u8{0x31} ** (std.math.maxInt(u16) + 1)),
    );
}

test "pack array" {
    try expect(packArray, 0, &[_]u8{0x90});
    try expect(packArray, 15, &[_]u8{0x9F});
    try expect(packArray, 16, &[_]u8{ 0xDC, 0x00, 0x10 });
    try expect(packArray, maxInt(u16), &[_]u8{ 0xDC, 0xFF, 0xFF });
    try expect(packArray, maxInt(u16) + 1, &[_]u8{ 0xDD, 0x00, 0x01, 0x00, 0x00 });
    try expect(packArray, maxInt(u32), &[_]u8{ 0xDD, 0xFF, 0xFF, 0xFF, 0xFF });
    try expect(packArray, maxInt(u32) + 1, error.ArrayTooLong);
}
