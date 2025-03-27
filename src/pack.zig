const mzg = @import("mzg.zig");
const std = @import("std");

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
///       `pub fn mzgPack(self: *@This(), writer: anytype) !void`, or
///       `pub fn mzgPack(self: *@This(), options: PackOptions, writer: anytype) !void`,
///       then it is called.
///     * If enum is non-exhaustive, it is packed as `int` using its value.
///     * Otherwise, if `options.@"enum"` is `.name`, then the name of the enum
///       is packed as `str`, otherwise, its value is packed `int`.
/// * Zig untyped enum literal -> `str`.
/// * Zig unions ->
///     * If the union has the method
///       `pub fn mzgPack(self: *@This(), writer: anytype) !void`, or
///       `pub fn mzgPack(self: *@This(), options: PackOptions, writer: anytype) !void`,
///       then it is called.
///     * Otherwise, if the union is a tagged union, it is packed as an `array` with 2
///       elements, the first being the tag enum, and the second being the actual value
///       of the union. How the tag enum is packed is decided by `options.@"enum"`.
///     * Otherwise, untagged unions cannot be packed.
/// * Zig structs ->
///     * If the struct has the method
///       `pub fn mzgPack(self: *@This(), writer: anytype) !void`, or
///       `pub fn mzgPack(self: *@This(), options: PackOptions, writer: anytype) !void`,
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
///   `str` if `options.byte_slice` is `.str`, otherwise, `bin`.
/// * Zig slices, arrays, sentinel-terminated pointers of other types -> `array`
///   of the elements.
/// * Zig `*T` -> packed as `T`
pub fn packWithOptions(
    value: anytype,
    options: PackOptions,
    writer: anytype,
) mzg.PackError(@TypeOf(writer))!void {
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
                @compileError(
                    "Cannot pack untagged union '" ++ @typeName(Value) ++ "'",
                );
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
                return mzg.packInt(
                    @as(info.backing_integer.?, @bitCast(value)),
                    writer,
                );
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
                                try packWithOptions(
                                    @field(value, field.name),
                                    options,
                                    writer,
                                );
                            }
                        } else {
                            try mzg.packStr(field.name, writer);
                            try packWithOptions(
                                @field(value, field.name),
                                options,
                                writer,
                            );
                        }
                    }
                },
                .full_map => {
                    try mzg.packMap(info.fields.len, writer);
                    inline for (info.fields) |field| {
                        try mzg.packStr(field.name, writer);
                        try packWithOptions(
                            @field(value, field.name),
                            options,
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
