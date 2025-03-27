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
                return out.mzgUnpack(buffer);
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
        .@"union" => |child| {
            if (std.meta.hasFn(Child, "mzgUnpack")) {
                return out.mzgUnpack(buffer);
            }

            if (child.tag_type == null) {
                @compileError("Cannot unpack untagged union '" ++ @typeName(Child) ++ "'");
            }

            const format = try mzg.format.parse(buffer);
            const expected_len: u8 = switch (format) {
                .array => 2,
                .map => 1,
                else => return mzg.UnpackError.TypeIncompatible,
            };

            var size: usize = 0;
            var len: u8 = undefined;

            size += try unpack(buffer, &len);
            if (len != expected_len) {
                return mzg.UnpackError.TypeIncompatible;
            }

            var tag: child.tag_type.? = undefined;
            size += try unpack(buffer[size..], &tag);

            inline for (child.fields) |field| {
                if (std.mem.eql(u8, field.name, @tagName(tag))) {
                    out.* = @unionInit(Child, field.name, undefined);
                    size += try unpack(
                        buffer[size..],
                        &@field(out.*, field.name),
                    );
                    return size;
                }
            }
            return mzg.UnpackError.ValueInvalid;
        },
        .@"struct" => |child| {
            if (std.meta.hasFn(Child, "mzgUnpack")) {
                return out.mzgUnpack(buffer);
            }

            var size: usize = 0;
            var len: usize = 0;

            if (child.is_tuple) {
                switch (try mzg.format.parse(buffer)) {
                    .array => size += try unpack(buffer, &len),
                    else => return mzg.UnpackError.TypeIncompatible,
                }
                if (len != child.fields.len) {
                    return mzg.UnpackError.TypeIncompatible;
                }
                inline for (0..child.fields.len) |i| {
                    size += try unpack(buffer[size..], &out.*[i]);
                }
                return size;
            }

            switch (try mzg.format.parse(buffer)) {
                .array => {
                    size += try unpack(buffer, &len);
                    if (len != child.fields.len) {
                        return mzg.UnpackError.TypeIncompatible;
                    }

                    inline for (0..child.fields.len) |i| {
                        size += try unpack(
                            buffer[size..],
                            &@field(out.*, child.fields[i].name),
                        );
                    }
                },
                .map => {
                    size += try unpack(buffer, &len);

                    var name: []const u8 = undefined;
                    for (0..len) |_| {
                        size += try unpack(buffer[size..], &name);

                        inline for (child.fields) |field| {
                            if (std.mem.eql(u8, field.name, name)) {
                                size += try unpack(
                                    buffer[size..],
                                    &@field(out.*, field.name),
                                );
                                break;
                            }
                        }
                    }
                },
                else => return mzg.UnpackError.TypeIncompatible,
            }
            return size;
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
