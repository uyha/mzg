<!-- markdownlint-disable no-inline-html -->
# mzg

<!--toc:start-->
- [mzg](#mzg)
  - [How to use](#how-to-use)
  - [API](#api)
    - [High level functions](#high-level-functions)
    - [Building block functions](#building-block-functions)
  - [Examples](#examples)
    - [Simple back and forth](#simple-back-and-forth)
    - [Default packing and unpacking for custom types](#default-packing-and-unpacking-for-custom-types)
    - [Adapters for common container types](#adapters-for-common-container-types)
  - [Mapping](#mapping)
    - [Default packing from Zig types to MessagePack](#default-packing-from-zig-types-to-messagepack)
    - [Default unpack from MessagePack to Zig types](#default-unpack-from-messagepack-to-zig-types)
    - [Customization](#customization)
      - [Packing](#packing)
      - [Unpacking](#unpacking)
<!--toc:end-->

`mzg` is a MessagePack library for Zig with no allocations, and the API favors
the streaming usage.

## How to use

1. Run the following command to add this project as a dependency

   ```sh
   zig fetch --save git+https://github.com/uyha/mzg.git#v0.0.7
   ```

1. In your `build.zig`, add the following

   ```zig
   const mzg = b.dependency("mzg", .{
       .target = target,
       .optimize = optimize,
   });
   // Replace `exe` with your actual library or executable
   exe.root_module.addImport("mzg", mzg.module("mzg"));
   ```

## API

### High level functions

1. `pack` for packing Zig values using a `writer`
1. `packWithOptions` is like `pack` but accepts a `mzg.PackOptions` parameter to
   control the packing behavior.
1. `unpack` for unpacking a MessagePack message into a Zig object
1. A set of adapters living in the `mzg.adapter` namespace to help with packing
   and unpacking common container types.

### Building block functions

There are a set of `pack*` and `unpack*` functions that translate between a
precise set of Zig types and MessagePack. These functions can be used when
implementing custom packing and unpacking.

## Examples

All examples live in [examples](examples) directory.

### Simple back and forth

Converting a byte slice to MessagePack and back

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    try mzg.pack(
        "a string with some characters for demonstration purpose",
        buffer.writer(allocator),
    );

    var string: []const u8 = undefined;
    const size = try mzg.unpack(buffer.items, &string);
    std.debug.print("Consumed {} bytes\n", .{size});
    std.debug.print("string: {s}\n", .{string});
}

const std = @import("std");
const mzg = @import("mzg");
```

### Default packing and unpacking for custom types

Certain types can be packed and unpacked by default (refer to
[Mapping](#mapping) for more details)

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    try mzg.pack(
        Targets{ .position = .init(2000), .velocity = .init(10) },
        buffer.writer(allocator),
    );

    var targets: Targets = undefined;
    const size = try mzg.unpack(buffer.items, &targets);

    std.debug.print("Consumed {} bytes\n", .{size});
    std.debug.print("Targets: {}\n", .{targets});
}

const Position = enum(i32) {
    _,
    pub fn init(raw: std.meta.Tag(@This())) @This() {
        return @enumFromInt(raw);
    }
};
const Velocity = enum(i32) {
    _,
    pub fn init(raw: std.meta.Tag(@This())) @This() {
        return @enumFromInt(raw);
    }
};
const Targets = struct {
    position: Position,
    velocity: Velocity,
};

const std = @import("std");
const mzg = @import("mzg");
const adapter = mzg.adapter;
```

### Adapters for common container types

Many container types in the `std` library cannot be packed or unpacked by
default, but the adapter functions make it easy to work with these types.

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    var in: std.ArrayListUnmanaged(u32) = .empty;
    defer in.deinit(allocator);
    try in.append(allocator, 42);
    try in.append(allocator, 75);
    try mzg.pack(adapter.packArray(&in), buffer.writer(allocator));

    var out: std.ArrayListUnmanaged(u32) = .empty;
    defer out.deinit(allocator);
    const size = try mzg.unpack(
        buffer.items,
        adapter.unpackArray(&out, allocator),
    );
    std.debug.print("Consumed {} bytes\n", .{size});
    std.debug.print("out: {any}\n", .{out.items});
}

const std = @import("std");
const mzg = @import("mzg");
const adapter = mzg.adapter;
```

## Mapping

### Default packing from Zig types to MessagePack

<!-- markdownlint-disable line-length -->
| Zig Type                                 | MessagePack                                               |
|------------------------------------------|-----------------------------------------------------------|
| `void`, `null`                           | `nil`                                                     |
| `bool`                                   | `bool`                                                    |
| integers (<=64 bits)                     | `int`                                                     |
| floats (<=64 bits)                       | `float`                                                   |
| `?T`                                     | `nil` if value is `null`, pack according to `T` otherwise |
| enums                                    | `int`                                                     |
| enum literals                            | `str`                                                     |
| tagged unions                            | `array` of 2 elements: `int` and the value of the union   |
| packed structs                           | `int`                                                     |
| structs and tuples                       | `array` of fields in the order they are declared          |
| `[N]`, `[]`, `[:X]`, and `@Vec` of `u8`  | `str`                                                     |
| `[N]`, `[]`, `[:X]`, and `@Vec` of `T`   | `array` of `T`                                            |
| `Ext`                                    | `ext`                                                     |
| `Timestamp`                              | `Timestamp`                                               |
| `*T`                                     | `T`                                                       |
<!-- markdownlint-enable line-length -->

### Default unpack from MessagePack to Zig types

| MessagePack | Compatible Zig Type                  |
|-------------|--------------------------------------|
| `nil`       | `void`, `?T`                         |
| `bool`      | `bool`                               |
| `int`       | integers, enums                      |
| `float`     | floats                               |
| `str`       | `[]const u8`                         |
| `bin`       | `[]const u8`                         |
| `array`     | The length can be read into integers |
| `map`       | The length can be read into integers |
| `ext`       | `Ext`                                |
| `Timestamp` | `Timestamp`                          |

### Customization

#### Packing

When an enum/union/struct has an `mzgPack` function that returns
`mzg.PackError(@TypeOf(writer))!void` can be called with

```zig
// Value cares about the options passed by the caller
value.mzgPack(options, writer);
```

- `value` is the enum/union/struct being packed.
- `options` is `mzg.PackOptions`.
- `writer` is `anytype` that can be called with `writer.writeAll(&[_]u8{});`.

The function will be called when the `mzg.pack` function is used.

#### Unpacking

When an enum/union/struct has an `mzgUnpack` function that returns
`UnpackError!usize` and can be called with

```zig
out.mzgUnpack(buffer);
```

- `out` is the enum/union/struct being unpacked.
- `buffer` is `[]const u8`.

The function will be called when the `mzg.unpack` function is used.
