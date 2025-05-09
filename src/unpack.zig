/// Unpack `[]const u8` to a Zig value
///
/// `out` has to be a mutable single-item pointer
///
/// `map` must be a tuple of 2 element tuples. The 2 element tuples must
/// have a type as their 1st element `T`, and the 2nd element must be a
/// function that accepts a `T` instance and returns a type that can be called
/// with `unpackImpl`.
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
fn unpackImpl(
    allocator: anytype,
    comptime map: anytype,
    buffer: []const u8,
    out: anytype,
) Error(@TypeOf(allocator))!usize {
    const Out = @TypeOf(out);
    const info = @typeInfo(Out);

    inline for (map) |item| {
        const T, const adapter = item;
        if (Out == *T) {
            return unpackImpl(allocator, map, buffer, adapter(out));
        }
    }

    switch (comptime @TypeOf(allocator)) {
        void => if (comptime hasFn(Out, "mzgUnpack")) {
            return out.mzgUnpack(map, buffer);
        },
        Allocator => if (comptime hasFn(Out, "mzgUnpackAllocate")) {
            return out.mzgUnpackAllocate(allocator, map, buffer);
        },
        else => @compileError(
            "implemation error, memory can only be `void` or `Allocator`",
        ),
    }

    if (comptime info != .pointer or info.pointer.size != .one or info.pointer.is_const) {
        @compileError(
            "`out` has to be a mutable singe-item pointer not " ++ @typeName(Out),
        );
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
                return unpackImpl(allocator, map, buffer, &out.*.?);
            },
        },
        .@"enum" => |E| {
            switch (comptime @TypeOf(allocator)) {
                void => if (comptime hasFn(Child, "mzgUnpack")) {
                    return out.mzgUnpack(map, buffer);
                },
                Allocator => if (comptime hasFn(Child, "mzgUnpackAllocate")) {
                    return out.mzgUnpackAllocate(allocator, map, buffer);
                },
                else => @compileError(
                    "implemation error, memory can only be `void` or `Allocator`",
                ),
            }

            switch (try mzg.format.parse(buffer)) {
                .int => {
                    var raw: E.tag_type = undefined;
                    const size = try unpackImpl(
                        allocator,
                        map,
                        buffer,
                        &raw,
                    );
                    out.* = std.meta.intToEnum(
                        Child,
                        raw,
                    ) catch return mzg.UnpackError.ValueInvalid;
                    return size;
                },
                .str => {
                    var view: []const u8 = undefined;
                    const size = try unpackImpl(
                        allocator,
                        map,
                        buffer,
                        &view,
                    );
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
            switch (comptime @TypeOf(allocator)) {
                void => if (comptime hasFn(Child, "mzgUnpack")) {
                    return out.mzgUnpack(map, buffer);
                },
                Allocator => if (comptime hasFn(Child, "mzgUnpackAllocate")) {
                    return out.mzgUnpackAllocate(allocator, map, buffer);
                },
                else => @compileError(
                    "implemation error, memory can only be `void` or `Allocator`",
                ),
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

            size += try unpackImpl(
                allocator,
                map,
                buffer,
                &len,
            );
            if (len != expected_len) {
                return mzg.UnpackError.TypeIncompatible;
            }

            var tag: child.tag_type.? = undefined;
            size += try unpackImpl(
                allocator,
                map,
                buffer[size..],
                &tag,
            );

            inline for (child.fields) |field| {
                if (std.mem.eql(u8, field.name, @tagName(tag))) {
                    out.* = @unionInit(Child, field.name, undefined);
                    size += try unpackImpl(
                        allocator,
                        map,
                        buffer[size..],
                        &@field(out.*, field.name),
                    );
                    return size;
                }
            }
            return mzg.UnpackError.ValueInvalid;
        },
        .@"struct" => |child| {
            switch (comptime @TypeOf(allocator)) {
                void => if (comptime hasFn(Child, "mzgUnpack")) {
                    return out.mzgUnpack(map, buffer);
                },
                Allocator => if (comptime hasFn(Child, "mzgUnpackAllocate")) {
                    return out.mzgUnpackAllocate(allocator, map, buffer);
                },
                else => @compileError(
                    "implemation error, memory can only be `void` or `Allocator`",
                ),
            }

            var size: usize = 0;
            var len: usize = 0;

            if (child.is_tuple) {
                switch (try mzg.format.parse(buffer)) {
                    .array => size += try unpackImpl(
                        allocator,
                        map,
                        buffer,
                        &len,
                    ),
                    else => return mzg.UnpackError.TypeIncompatible,
                }
                if (len != child.fields.len) {
                    return mzg.UnpackError.TypeIncompatible;
                }
                inline for (0..child.fields.len) |i| {
                    size += try unpackImpl(
                        allocator,
                        map,
                        buffer[size..],
                        &out.*[i],
                    );
                }
                return size;
            }

            if (child.layout == .@"packed") {
                return unpackImpl(
                    allocator,
                    map,
                    buffer,
                    @as(*child.backing_integer.?, @ptrCast(out)),
                );
            }

            switch (try mzg.format.parse(buffer)) {
                .array => {
                    size += try unpackImpl(
                        allocator,
                        map,
                        buffer,
                        &len,
                    );
                    if (len != child.fields.len) {
                        return mzg.UnpackError.TypeIncompatible;
                    }

                    inline for (0..child.fields.len) |i| {
                        size += try unpackImpl(
                            allocator,
                            map,
                            buffer[size..],
                            &@field(out.*, child.fields[i].name),
                        );
                    }
                },
                .map => {
                    size += try unpackImpl(
                        allocator,
                        map,
                        buffer,
                        &len,
                    );

                    var name: []const u8 = undefined;
                    for (0..len) |_| {
                        size += try unpackImpl(
                            allocator,
                            map,
                            buffer[size..],
                            &name,
                        );

                        inline for (child.fields) |field| {
                            if (std.mem.eql(u8, field.name, name)) {
                                size += try unpackImpl(
                                    allocator,
                                    map,
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

pub fn unpackAdaptedAllocate(
    allocator: Allocator,
    comptime map: anytype,
    buffer: []const u8,
    out: anytype,
) mzg.UnpackAllocateError!usize {
    return unpackImpl(allocator, map, buffer, out);
}

pub fn unpackAllocate(
    allocator: Allocator,
    buffer: []const u8,
    out: anytype,
) mzg.UnpackAllocateError!usize {
    return unpackImpl(allocator, .{}, buffer, out);
}

pub fn unpackAdapted(
    comptime map: anytype,
    buffer: []const u8,
    out: anytype,
) mzg.UnpackAllocateError!usize {
    return unpackImpl({}, map, buffer, out);
}

pub fn unpack(buffer: []const u8, out: anytype) mzg.UnpackError!usize {
    return unpackImpl({}, .{}, buffer, out);
}

fn Error(T: type) type {
    return switch (T) {
        void => UnpackError,
        Allocator => UnpackAllocateError,
        else => @compileError(
            @typeName(T) ++ " is not supported",
        ),
    };
}

const mzg = @import("root.zig");
const UnpackError = mzg.UnpackError;
const UnpackAllocateError = mzg.UnpackAllocateError;

const std = @import("std");
const Allocator = std.mem.Allocator;
const hasFn = std.meta.hasFn;
