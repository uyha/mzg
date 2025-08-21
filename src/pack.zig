pub const PackOptions = struct {
    const Self = @This();

    /// This field decides if a byte slice like value (`[N]u8`, `[]u8`, etc.) should be
    /// packed as a `str` or a `bin`.
    byte_slice: enum { str, bin } = .str,
    /// This field decides if an enum / tagged union is packed using its name or value.
    /// A Non-exhaustive enum will always be packed as its value. It also does not
    /// affect how enum literals are packed as they will always be packed as using their
    /// names.
    @"enum": enum { name, value } = .value,
    /// This field decides if a struct is packed as an array or a map. A tuple is always
    /// packed as an array. `.map` will skip null values while `.full_map` will keep
    /// them.
    @"struct": enum { array, map, full_map } = .array,

    /// Pack everything as small as possible.
    pub const default: Self = .{};
    /// Like `default` but pack byte slice as `bin` instead of `str`.
    pub const bin: Self = .{ .byte_slice = .bin };
    /// Pack enums and errors as strings. Pack structs as maps with field names being
    /// the keys, and null fields are skipped.
    pub const stringly: Self = .{
        .byte_slice = .str,
        .@"enum" = .name,
        .@"struct" = .map,
    };
    /// Similar to `.stringly` but null fields in structs are not skipped.
    pub const full_stringly: Self = .{
        .byte_slice = .str,
        .@"enum" = .name,
        .@"struct" = .full_map,
    };
};

/// Pack the given Zig value as MessagePack
///
/// This functions provides 2 ways for customization, the `map` and `options`
/// parameters.
/// * The `map` parameter allows customization for types that you do
///   not own and hence cannot modify it.
/// * The `options` parameter allows customization for builtin types that is
///   supported by this function.
///
/// `map` must be a tuple of 2 element tuples. The 2 element tuples must
/// have a type as their 1st element `T`, and the 2nd element must be a
/// function that accepts a `T` instance and returns a type that can be called
/// with `packAdaptedWithOptions`.
///
/// Supported types:
/// * Zig `null` and `void` -> `nil`.
/// * Zig `bool` -> `bool`.
/// * Zig `u8`, `i16`, `comptime_int`, etc. -> `int`. The packing uses the least
///   amount of bytes based on the value.
/// * Zig `f16`, `f32`, `f64`, `comptime_float`, etc. -> `float`.
///     * `f16` is converted to `f32` and then gets packed as `f32`.
///     * `comptime_float` is converted to `f64` and then gets packed as `f64`.
/// * Zig optionals -> `nil` if it is null, otherwise, packed as the corresponding
///   `child` type.
/// * Zig enums ->
///     * If the enum has the method
///       `pub fn mzgPack(
///         self: *@This(),
///         options: PackOptions,
///         writer: *Writer,
///       ) PackError!void`,
///       then it is called.
///     * If enum is non-exhaustive, it is packed as `int` using its value.
///     * Otherwise, if `options.@"enum"` is `.name`, then the name of the enum
///       is packed as `str`, otherwise, its value is packed `int`.
/// * Zig untyped enum literal -> `str`.
/// * Zig unions ->
///     * If the union has the method
///       `pub fn mzgPack(
///         self: *@This(),
///         options: PackOptions,
///         writer: *Writer,
///       ) PackError!void`,
///       then it is called.
///     * Otherwise, if the union is a tagged union, it is packed as an `array` with 2
///       elements, the first being the tag enum, and the second being the actual value
///       of the union. How the tag enum is packed is decided by `options.@"enum"`.
///     * Otherwise, untagged unions cannot be packed.
/// * Zig structs ->
///     * If the struct has the method
///       `pub fn mzgPack(
///         self: *@This(),
///         options: PackOptions,
///         writer: *Writer,
///       ) PackError!void`,
///       then it is called.
///     * Otherwise, if it is a tuple, all the fields are packed in an `array` in the
///       order they are declared.
///     * Otherwise, if it is a packed struct, its backing integer is packed as an int.
///     * Otherwise, if it is a normal struct, if `options.@"struct"`
///         * is `.array`, the fields are packed in an `array` in the other
///           they are declared.
///         * is `.map`, the fields are packed in a `map`, with the keys
///           being their names and the values being their values. In this
///           case, if `options.skip_null` is `true`, null fields will be
///           skipped.
/// * Zig slices, arrays, sentinel-terminated pointers, and @Vector of `u8` ->
///   `str` if `options.byte_slice` is `.str`, otherwise, `.bin`.
/// * Zig slices, arrays, sentinel-terminated pointers of other types -> `array`
///   of the elements.
/// * Zig `*T` -> packed as `T`
pub fn packAdaptedWithOptions(
    value: anytype,
    options: PackOptions,
    comptime map: anytype,
    writer: *Writer,
) PackError!void {
    const Value = @TypeOf(value);

    inline for (map) |entry| {
        const T, const adapter = entry;
        switch (Value) {
            T, *T, *const T => return packAdaptedWithOptions(
                adapter(value),
                options,
                map,
                writer,
            ),
            else => {},
        }
    }

    switch (@typeInfo(Value)) {
        .null, .void => try mzg.packNil(writer),
        .bool => try mzg.packBool(value, writer),
        .comptime_int, .int => try mzg.packInt(value, writer),
        .comptime_float, .float => try mzg.packFloat(value, writer),
        .optional => {
            if (value) |payload| {
                return packAdaptedWithOptions(payload, options, map, writer);
            } else {
                return mzg.packNil(writer);
            }
        },
        .@"enum" => |info| {
            if (std.meta.hasFn(Value, "mzgPack")) {
                return value.mzgPack(options, map, writer);
            }
            if (!info.is_exhaustive) {
                return mzg.packInt(@intFromEnum(value), writer);
            }
            switch (options.@"enum") {
                .value => return mzg.packInt(@intFromEnum(value), writer),
                .name => return mzg.packStr(@tagName(value), writer),
            }
        },
        .enum_literal => {
            return mzg.packStr(@tagName(value), writer);
        },
        .@"union" => |info| {
            if (std.meta.hasFn(Value, "mzgPack")) {
                return value.mzgPack(options, map, writer);
            }

            if (info.tag_type != null) {
                switch (value) {
                    inline else => |payload, tag| return packAdaptedWithOptions(
                        .{ tag, payload },
                        options,
                        map,
                        writer,
                    ),
                }
            } else {
                @compileError(
                    "Cannot pack untagged union '" ++ @typeName(Value) ++ "'",
                );
            }
        },
        .@"struct" => |info| {
            if (std.meta.hasFn(Value, "mzgPack")) {
                return value.mzgPack(options, map, writer);
            }
            if (info.is_tuple) {
                try mzg.packArray(info.fields.len, writer);
                inline for (info.fields) |field| {
                    try packAdaptedWithOptions(
                        @field(value, field.name),
                        options,
                        map,
                        writer,
                    );
                }
                return;
            }
            if (info.layout == .@"packed") {
                return mzg.packInt(
                    @as(info.backing_integer.?, @bitCast(value)),
                    writer,
                );
            }

            switch (options.@"struct") {
                .array => {
                    try mzg.packArray(info.fields.len, writer);
                    inline for (info.fields) |field| {
                        try packAdaptedWithOptions(
                            @field(value, field.name),
                            options,
                            map,
                            writer,
                        );
                    }
                },
                .map => {
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
                                try packAdaptedWithOptions(
                                    @field(value, field.name),
                                    options,
                                    map,
                                    writer,
                                );
                            }
                        } else {
                            try mzg.packStr(field.name, writer);
                            try packAdaptedWithOptions(
                                @field(value, field.name),
                                options,
                                map,
                                writer,
                            );
                        }
                    }
                },
                .full_map => {
                    try mzg.packMap(info.fields.len, writer);
                    inline for (info.fields) |field| {
                        try mzg.packStr(field.name, writer);
                        try packAdaptedWithOptions(
                            @field(value, field.name),
                            options,
                            map,
                            writer,
                        );
                    }
                },
            }
        },
        .error_union => {
            if (value) |payload| {
                try mzg.packArray(writer, 2);
                try mzg.packInt(writer, 0);
                try packAdaptedWithOptions(payload, options, map, writer);
            } else |err| {
                try mzg.packArray(writer, 1);
                try packAdaptedWithOptions(err, options, map, writer);
            }
        },
        .pointer => |ptr| switch (ptr.size) {
            .one => switch (@typeInfo(ptr.child)) {
                .array => {
                    const Slice = []const std.meta.Elem(ptr.child);
                    return packAdaptedWithOptions(
                        @as(Slice, value),
                        options,
                        map,
                        writer,
                    );
                },
                else => return packAdaptedWithOptions(
                    value.*,
                    options,
                    map,
                    writer,
                ),
            },
            .many, .slice => {
                if (ptr.size == .many and ptr.sentinel() == null) {
                    @compileError(
                        "Cannot pack '" ++ @typeName(Value) ++ "' without sentinel",
                    );
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
                    try packAdaptedWithOptions(elem, options, map, writer);
                }
                return;
            },
            else => @compileError("Cannot pack '" ++ @typeName(Value) ++ "'"),
        },
        .array => return packAdaptedWithOptions(&value, options, map, writer),
        .vector => |vec| {
            const array: [vec.len]vec.child = value;
            return packAdaptedWithOptions(&array, options, map, writer);
        },

        else => @compileError("'" ++ @typeName(Value) ++ "' is not supported"),
    }
}

/// Calls `packAdaptedWithOptions` with empty map
pub fn packWithOptions(
    value: anytype,
    options: PackOptions,
    writer: *Writer,
) PackError!void {
    return packAdaptedWithOptions(value, options, comptime .{}, writer);
}

/// Calls `packAdaptedWithOptions` with `.default` options
pub fn packAdapted(
    value: anytype,
    comptime map: anytype,
    writer: *Writer,
) PackError!void {
    return packAdaptedWithOptions(value, comptime .default, map, writer);
}

/// Calls `packWithOptions` with `.default` options
pub fn pack(value: anytype, writer: *Writer) mzg.PackError!void {
    return packWithOptions(value, comptime .default, writer);
}

const std = @import("std");
const Writer = std.Io.Writer;

const mzg = @import("root.zig");
const PackError = mzg.PackError;
