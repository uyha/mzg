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
   zig fetch --save git+https://github.com/uyha/mzg.git#v0.2.1
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

### Packing functions

1. `pack` is for packing Zig values using a `writer`
1. `packAdapted` is like `pack` but it accepts a map that defines how certain
   types should be packed.
1. `packWithOptions` is like `pack` but it accepts a `mzg.PackOptions` parameter
   to control the packing behavior.
1. `packAdaptedWithOptions` is like `packWithOptions` but it accepts a map that
   defines how certain types should be packed.

### Unpacking functions

1. `unpack` is for unpacking a MessagePack message into a Zig object and it does
   not allocate memory.
1. `unpackAdapted` is like `unpack` but it accepts a map that defines how
   certain types should be unpacked.
1. `unpackAllocate` is like `unpack` but it accepts an `Allocator` that allows
   the unpacking process to allocate memory.
1. `unpackAdaptedAllocate` is like `unpackAllocate` but it accepts a map that
   defines how a particular type should be packed.

### Adapters

1. `adapter.packArray` and `adapter.unpackArray` pack and unpack structs like
   `std.ArrayListUnmanaged`
1. `adapter.packMap` and `adapter.unpackMap` pack and unpack structs like
   `std.ArrayHashMapUnmanaged`.
1. `adapter.packStream` and `adapter.unpackStream` pack and unpack structs in a
   stream like manner (length is not specified in the beginning).

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

    var allocWriter: Writer.Allocating = .init(allocator);
    defer allocWriter.deinit();
    const writer: *Writer = &allocWriter.writer;

    try mzg.pack(
        "a string with some characters for demonstration purpose",
        writer,
    );

    var string: []const u8 = undefined;
    const size = try mzg.unpack(writer.buffer[0..writer.end], &string);
    std.debug.print("Consumed {} bytes\n", .{size});
    std.debug.print("string: {s}\n", .{string});
}

const std = @import("std");
const Writer = std.Io.Writer;

const mzg = @import("mzg");
```

### Default packing and unpacking for custom types

Certain types can be packed and unpacked by default (refer to
[Mapping](#mapping) for more details)

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var allocWriter: Writer.Allocating = .init(allocator);
    defer allocWriter.deinit();
    const writer: *Writer = &allocWriter.writer;

    try mzg.pack(
        Targets{ .position = .init(2000), .velocity = .init(10) },
        writer,
    );

    var targets: Targets = undefined;
    const size = try mzg.unpack(writer.buffer[0..writer.end], &targets);

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
const Writer = std.Io.Writer;

const mzg = @import("mzg");
const adapter = mzg.adapter;
```

### Adapters for common container types

Many container types in the `std` library cannot be packed or unpacked by
default, but the adapter functions make it easy to work with these types.

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var allocWriter: Writer.Allocating = .init(allocator);
    defer allocWriter.deinit();
    const writer: *Writer = &allocWriter.writer;

    var in: std.ArrayList(u32) = .empty;
    defer in.deinit(allocator);
    try in.append(allocator, 42);
    try in.append(allocator, 75);
    try mzg.pack(adapter.packArray(&in), writer);

    var out: std.ArrayList(u32) = .empty;
    defer out.deinit(allocator);
    const size = try mzg.unpackAllocate(
        allocator,
        writer.buffer[0..writer.end],
        adapter.unpackArray(&out),
    );
    std.debug.print("Consumed {} bytes\n", .{size});
    std.debug.print("out: {any}\n", .{out.items});
}

const std = @import("std");
const Writer = std.Io.Writer;

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
`mzg.PackError!void` can be called with

```zig
// Value cares about the options passed by the caller
value.mzgPack(options, map, writer);
```

With the arguments being

- `value` is the enum/union/struct being packed.
- `options` is `mzg.PackOptions`.
- `map` is a tuple of 2 element tuples whose 1st element being a type and 2nd
  element being a packing adapter function.
- `writer` is `std.Io.Writer`.

The function will be called when the `mzg.pack` function is used.

#### Unpacking

When an enum/union/struct has

- `mzgUnpack` function that returns `UnpackError!usize` and can be called with

  ```zig
  out.mzgUnpack(map, buffer);
  ```

- `mzgUnpackAllocate` function that returns `UnpackAllocateError!usize` and can
  be called with

  ```zig
  out.mzgUnpackAllocate(allocator, map, buffer);
  ```

With the arguments being

- `out` is the enum/union/struct being unpacked.
- `allocator` is an `std.mem.Allocator`.
- `map` is a tuple of 2 element tuples whose 1st element being a type and 2nd
  element being an unpacking adapter function.
- `buffer` is `[]const u8`.

The `mzgUnpack` function is called when either `mzg.unpack` or
`mzg.unpackAdapted` is used.

The `mzgUnpackAllocate` function is called when either `mzg.unpackAllocate` or
`mzg.unpackAdaptedAllocate` is used.
