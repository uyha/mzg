const std = @import("std");
const mzg = @import("mzg.zig");

pub fn unpack(buffer: []const u8, out: anytype) mzg.UnpackError!usize {
    const Out = @TypeOf(out);
    const info = @typeInfo(Out);
    if (comptime info != .pointer or info.pointer.size != .one) {
        @compileError("`out` has to be a singe-item pointer");
    }
    const Child = info.pointer.child;

    switch (@typeInfo(Child)) {
        .void => return mzg.unpackNil(buffer, out),
        .bool => return mzg.unpackBool(buffer, out),
        .int => switch (try mzg.format.parse(buffer)) {
            .int => return mzg.unpackInt(buffer, out),
            .array => return mzg.unpackArray(buffer, out),
            .map => return mzg.unpackMap(buffer, out),
            else => return mzg.UnpackError.TypeIncompatible,
        },
        .float => return mzg.unpackFloat(buffer, out),
        .optional => switch (try mzg.format.parse(buffer)) {
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

            switch (try mzg.format.parse(buffer)) {
                .int => {
                    var raw: E.tag_type = undefined;
                    const size = try unpack(buffer, &raw);
                    out.* = std.meta.intToEnum(
                        Child,
                        raw,
                    ) catch return mzg.UnpackError.ValueInvalid;
                    return size;
                },
                .str => {
                    var view: []const u8 = undefined;
                    const size = try unpack(buffer, &view);
                    out.* = std.meta.stringToEnum(
                        Child,
                        view,
                    ) orelse return mzg.UnpackError.ValueInvalid;
                    return size;
                },
                else => return mzg.UnpackError.TypeIncompatible,
            }
        },
        .pointer => {
            if (Child != []const u8) {
                @compileError("'" ++ @typeName(Out) ++ "' is not supported");
            }
            return switch (try mzg.format.parse(buffer)) {
                .str => mzg.unpackStr(buffer, out),
                .bin => mzg.unpackBin(buffer, out),
                else => mzg.UnpackError.TypeIncompatible,
            };
        },
        else => @compileError("'" ++ @typeName(Out) ++ "' is not supported"),
    }
}
