const std = @import("std");

const builtin = @import("builtin");

const utils = @import("utils.zig");
const asBigEndianBytes = utils.asBigEndianBytes;

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
            try writer.writeAll(& //
                [_]u8{0xCB} // marker
                ++ asBigEndianBytes(endian, @as(f64, input)) // value
            );
        },
        f16 => {
            try writer.writeAll(& //
                [_]u8{0xCa} //marker
                ++ asBigEndianBytes(endian, @as(f32, input)) // value
            );
        },
        f32, f64 => {
            try writer.writeAll(& //
                [_]u8{if (Input == f32) 0xCA else 0xCB} //marker
                ++ asBigEndianBytes(endian, input) // value
            );
        },
        else => unreachable,
    }
}
pub fn packFloat(writer: anytype, input: anytype) @TypeOf(writer).Error!void {
    return packFloatWithEndian(comptime builtin.target.cpu.arch.endian(), writer, input);
}
