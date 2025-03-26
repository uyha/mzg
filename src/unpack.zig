const std = @import("std");

const UnpackError = @import("error.zig").UnpackError;
const format = @import("format.zig");

pub fn unpack(buffer: []const u8, out: anytype) UnpackError!usize {
    const Out = @TypeOf(out);
    const info = @typeInfo(Out);
    if (comptime info != .pointer or info.pointer.size != .one) {
        @compileError("`out` has to be a singe-item pointer");
    }
    const Child = info.pointer.child;

    switch (@typeInfo(Child)) {
        .void => return @import("nil.zig").unpackNil(buffer, out),
        .bool => return @import("bool.zig").unpackBool(buffer, out),
        .int => return @import("int.zig").unpackInt(buffer, out),
        .float => return @import("float.zig").unpackFloat(buffer, out),
        .optional => switch (try format.parse(buffer)) {
            .nil => {
                out.* = null;
                return 1;
            },
            else => {
                out.* = undefined;
                return unpack(buffer, &out.*.?);
            },
        },
        .@"enum" => |E| {
            if (std.meta.hasFn(Child, "mzgUnpack")) {
                return Child.mzgUnpack(buffer, out);
            }

            switch (try format.parse(buffer)) {
                .int => {
                    var raw: E.tag_type = undefined;
                    if (unpack(buffer, &raw)) |size| {
                        out.* = std.meta.intToEnum(
                            Child,
                            raw,
                        ) catch return UnpackError.ValueInvalid;
                        return size;
                    } else |err| {
                        return err;
                    }
                },
                .str => {
                    var view: []const u8 = undefined;
                    const size = try unpack(buffer, &view);
                    out.* = std.meta.stringToEnum(
                        Child,
                        view,
                    ) orelse return UnpackError.ValueInvalid;
                    return size;
                },
                else => return UnpackError.TypeIncompatible,
            }
        },
        .pointer => {
            if (Child != []const u8) {
                @compileError("'" ++ @typeName(Out) ++ "' is not supported");
            }
            return switch (try format.parse(buffer)) {
                .str => @import("str.zig").unpackStr(buffer, out),
                .bin => @import("bin.zig").unpackBin(buffer, out),
                else => UnpackError.TypeIncompatible,
            };
        },
        else => @compileError("'" ++ @typeName(Out) ++ "' is not supported"),
    }
}
