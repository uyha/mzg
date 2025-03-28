const std = @import("std");
const mzg = @import("mzg.zig");

/// Unpack `[]const u8` to a Zig value
///
/// `out` has to be a single-item pointer
///
/// Supported `child` of `out`:
/// * Zig `void` accepts `nil` messages.
/// * Zig `bool` accepts `bool` messages.
/// * Zig runtime ints (<= 64 bits) accept `int` messages, and the length of
///   `array`/`map` messages.
/// * Zig `f32` and `f64` accept `float` messages.
/// * Zig optionals gets assgin `null` if the message is `nil`, else the child type is
///   unpacked.
/// * Zig enum:
///     * If the enum has the method
///     `pub fn mzgUnpack(self: @This(), buffer: []const u8) UnpackError!usize`, it is
///     called.
///     * Otherwise, `int` and `str` messages are accepted.
///     * The `ValueInvalid` error is returned when the message does not match any a
///       valid enum member.
/// * Zig tagged unions:
///     * If the union has the method
///       `pub fn mzgUnpack(self: @This(), buffer: []const u8) UnpackError!usize`, it is
///       called.
///     * Otherwise, `array` messages with 2 elements or `map` messages with 1 element
///       are accepted.
///       * For `array` messages, the first element has to be an `int` and it is unpacked
///         as the tag type. The second element is unpacked as the union according to
///         the tag.
///       * For `map` messages, the key has to be a `str` and it is unpacked as the tag
///         type. The value is unpacked as the union according to the tag.
/// * Zig structs:
///     * If the struct has the method
///       `pub fn mzgUnpack(self: @This(), buffer: []const u8) UnpackError!usize`, it is
///       called.
///     * Otherwise, if it is
///         * A tuple, then `array` messages are accepted and, the elements in the
///           message are unpacked into the fields in the order the fields are declared.
///         * A packed struct, then `int` messages are accept and unpacked as its
///           backing integer.
///         * A normal struct, then `array` messages are accepted and, the elements in
///           the message are unpacked into the fields in the order the fields are
///           declared.
/// * Zig `[]const u8` accepts `str` and `bin` message. `out` will point to the slice
///   inside buffer. Hence no copy is done but it also means that `buffer` has to stay
///   alive when `out` is being used.
pub fn unpack(buffer: []const u8, out: anytype) mzg.UnpackError!usize {
    const Out = @TypeOf(out);
    const info = @typeInfo(Out);
    if (comptime std.meta.hasFn(Out, "mzgUnpack")) {
        return out.mzgUnpack(buffer);
    }
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

            if (child.layout == .@"packed") {
                return unpack(buffer, @as(*child.backing_integer.?, @ptrCast(out)));
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
