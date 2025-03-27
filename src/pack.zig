const mzg = @import("mzg.zig");
const std = @import("std");

pub const PackOptions = struct {
    const Self = @This();

    /// This field decides if a byte slice like value (`[N]u8`, `[]u8`, etc.) should be
    /// packed as a `str` or a `bin`.
    byte_slice: enum { str, bin } = .bin,
    /// This field decides if an enum / tagged union should be packed using its name or
    /// value. If the enum is packed using its name, it cannot be a non-exhaustive enum.
    @"enum": enum { name, value } = .value,
    /// This field decides if a struct is packed as an array or a map. A tuple is always
    /// packed as an array.
    @"struct": enum { array, map } = .array,
    /// This field decides if a field being null in a struct is skipped or not. It only
    /// has an effect when `@"struct"` is `.map` and it does not affect how a tuple is
    /// packed.
    skip_null: bool = true,

    /// Pack everything as small as possible.
    pub const default: Self = .{};
    /// Pack enums and errors as strings. Pack structs as maps with field names being the
    /// keys, and null fields are skipped.
    pub const stringly: Self = .{
        .byte_slice = .str,
        .@"enum" = .name,
        .@"struct" = .map,
    };
    /// Similar to `.stringly` but null fields in structs are not skipped.
    pub const full_stringly: Self = .{
        .byte_slice = .str,
        .@"enum" = .name,
        .@"struct" = .map,
        .skip_null = false,
    };
};

/// Pack the given Zig value as MessagePack
///
/// Supported types:
/// * Zig `null` and `void` -> `nil`.
/// * Zig `bool` -> `bool`.
/// * Zig `u8`, `i16`, `comptime_int`, etc. -> `int`. The packing uses the least
///   amount of bytes based on the value.
/// * Zig `f16`, `f32`, `f64`, `comptime_float`, etc. -> `float`.
///     * `f16` is converted to `f32` and then gets packed as `f32`.
///     * `comptime_float` is converted to `f64` and then gets packed as `f64`.
/// * Zig optionals -> `nil` if it is null, otherwise, packed as the
///   corresponding `child` type.
/// * Zig enums ->
///     * If the enum has the method
///       `pub fn mzgPack(self: *@This(), packer: anytype) !void`, it is called
///       with `packer` being a pointer to a constant packer.
///     * Othwerwise, if `behavior.@"enum"` is `.name`, then the name of the enum
///       is packed as a str, otherwise, its value is packed an int.
///       Non-exhaustive enums cannot be used with `behavior.@"enum"` being
///       `.name`.
/// * Zig untyped enum literal -> Can only be packed if `behavior.@"enum"` is
///   `.name`. The name of the enum is packed as a str.
/// * Zig tagged unions ->
///     * If the union has the method
///       `pub fn mzgPack(self: *@This(), packer: anytype) !void`, it is called
///       with `packer` being a pointer to a constant packer.
///     * Otherwise, it is packed as an `array` with 2 elements, the first being
///       the tag enum, and the second being the actual value of the union. How
///       the tag enum is packed is decided by `behavior.@"enum"`. Untagged
///       unions cannot be packed.
/// * Zig structs ->
///     * If the struct has the method
///       `pub fn mzgPack(self: *@This(), packer: anytype) !void`, it is called
///       with `packer` being a pointer to a constant packer.
///     * Otherwise, if it is
///         * a tuple, all the fields are packed in an `array` in the order they
///           are declared.
///         * a normal struct, if `behavior.@"struct"`
///             * is `.array`, the fields are packed in an `array` in the other
///               they are declared.
///             * is `.map`, the fields are packed in a `map`, with the keys
///               being their names and the values being their values. In this
///               case, if `behavior.skip_null` is `true`, null fields will be
///               skipped.
/// * Zig slices, arrays, sentinel-terminated pointers, and @Vector of `u8` ->
///   `str` if `behavior.byte_slice` is `.str`, otherwise, `bin`.
/// * Zig slices, arrays, sentinel-terminated pointers of other types -> `array`
///   of the elements.
/// * Zig `*T` -> packed as `T`
pub fn packWithOptions(
    value: anytype,
    options: PackOptions,
    writer: anytype,
) mzg.PackError(@TypeOf(writer))!void {
    const Error = mzg.PackError(@TypeOf(writer));
    const Value = @TypeOf(value);
    switch (@typeInfo(Value)) {
        .null, .void => try mzg.packNil(writer),
        .bool => try mzg.packBool(value, writer),
        .comptime_int, .int => try mzg.packInt(value, writer),
        .comptime_float, .float => try mzg.packFloat(value, writer),
        .optional => {
            if (value) |payload| {
                return packWithOptions(payload, options, writer);
            } else {
                return mzg.packNil(writer);
            }
        },
        .@"enum" => |info| {
            if (std.meta.hasFn(Value, "mzgPack")) {
                switch (@typeInfo(@TypeOf(Value.mzgPack)).@"fn".params.len) {
                    2 => return value.mzgPack(writer),
                    3 => return value.mzgPack(options, writer),
                    else => @compileError(
                        "mzgPack function can only have either 2 or 3 arguments",
                    ),
                }
            }
            switch (options.@"enum") {
                .value => return mzg.packInt(@intFromEnum(value), writer),
                .name => {
                    if (!info.is_exhaustive) {
                        return Error.Unsupported;
                    }
                    return mzg.packStr(@tagName(value), writer);
                },
            }
        },
        .enum_literal => {
            if (options.@"enum" == .value) {
                return Error.Unsupported;
            }

            return mzg.packStr(@tagName(value), writer);
        },
        .@"union" => |info| {
            if (std.meta.hasFn(Value, "mzgPack")) {
                switch (@typeInfo(@TypeOf(Value.mzgPack)).@"fn".params.len) {
                    2 => return value.mzgPack(writer),
                    3 => return value.mzgPack(options, writer),
                    else => @compileError(
                        "mzgPack function can only have either 2 or 3 arguments",
                    ),
                }
            }

            if (info.tag_type != null) {
                switch (value) {
                    inline else => |payload, tag| return packWithOptions(
                        .{ tag, payload },
                        options,
                        writer,
                    ),
                }
            } else {
                @compileError("Cannot pack untagged union '" ++ @typeName(Value) ++ "'");
            }
        },
        .@"struct" => |info| {
            if (std.meta.hasFn(Value, "mzgPack")) {
                switch (@typeInfo(@TypeOf(Value.mzgPack)).@"fn".params.len) {
                    2 => return value.mzgPack(writer),
                    3 => return value.mzgPack(options, writer),
                    else => @compileError(
                        "mzgPack function can only have either 2 or 3 arguments",
                    ),
                }
            }
            if (info.is_tuple) {
                try mzg.packArray(info.fields.len, writer);
                inline for (info.fields) |field| {
                    try packWithOptions(
                        @field(value, field.name),
                        options,
                        writer,
                    );
                }
                return;
            }
            if (info.layout == .@"packed") {
                return mzg.packInt(@as(info.backing_integer.?, @bitCast(value)), writer);
            }

            switch (options.@"struct") {
                .array => {
                    try mzg.packArray(info.fields.len, writer);
                    inline for (info.fields) |field| {
                        try packWithOptions(
                            @field(value, field.name),
                            options,
                            writer,
                        );
                    }
                },
                .map => {
                    if (options.skip_null) {
                        var non_null_len: usize = 0;
                        inline for (info.fields) |field| {
                            if (@typeInfo(field.type) == .optional) {
                                if (@field(value, field.name) != null) {
                                    non_null_len += 1;
                                }
                            } else {
                                non_null_len += 1;
                            }
                        }

                        try mzg.packMap(non_null_len, writer);
                        inline for (info.fields) |field| {
                            if (@typeInfo(field.type) == .optional) {
                                if (@field(value, field.name) != null) {
                                    try mzg.packStr(field.name, writer);
                                    try packWithOptions(@field(value, field.name), options, writer);
                                }
                            } else {
                                try mzg.packStr(field.name, writer);
                                try packWithOptions(@field(value, field.name), options, writer);
                            }
                        }
                    } else {
                        try mzg.packMap(info.fields.len, writer);
                        inline for (info.fields) |field| {
                            try mzg.packStr(field.name, writer);
                            try packWithOptions(@field(value, field.name), options, writer);
                        }
                    }
                },
            }
        },
        .error_union => {
            if (value) |payload| {
                try mzg.packArray(writer, 2);
                try mzg.packInt(writer, 0);
                try packWithOptions(payload, options, writer);
            } else |err| {
                try mzg.packArray(writer, 1);
                try packWithOptions(err, options, writer);
            }
        },
        .pointer => |ptr| switch (ptr.size) {
            .one => switch (@typeInfo(ptr.child)) {
                .array => {
                    const Slice = []const std.meta.Elem(ptr.child);
                    return packWithOptions(@as(Slice, value), options, writer);
                },
                else => return packWithOptions(value.*, options, writer),
            },
            .many, .slice => {
                if (ptr.size == .many and ptr.sentinel() == null) {
                    @compileError("Cannot pack '" ++ @typeName(Value) ++ "' without sentinel");
                }

                const slice = if (ptr.size == .many) std.mem.span(value) else value;

                if (ptr.child == u8) {
                    return switch (options.byte_slice) {
                        .str => mzg.packStr(slice, writer),
                        .bin => mzg.packBin(slice, writer),
                    };
                }

                try mzg.packArray(slice.len, writer);
                for (slice) |elem| {
                    try packWithOptions(elem, options, writer);
                }
                return;
            },
            else => @compileError("Cannot pack '" ++ @typeName(Value) ++ "'"),
        },
        .array => return packWithOptions(&value, options, writer),
        .vector => |vec| {
            const array: [vec.len]vec.child = value;
            return packWithOptions(&array, options, writer);
        },

        else => @compileError("'" ++ @typeName(Value) ++ "' is not supported"),
    }
}

/// Calls `packWithOptions` with `.default` options
pub fn pack(value: anytype, writer: anytype) mzg.PackError(@TypeOf(writer))!void {
    return packWithOptions(value, comptime .default, writer);
}
