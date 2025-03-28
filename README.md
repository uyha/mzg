<!-- markdownlint-disable no-inline-html -->
# mzg

<!--toc:start-->
- [mzg](#mzg)
  - [How to use](#how-to-use)
  - [API](#api)
    - [High level functions](#high-level-functions)
  - [Example](#example)
    - [Streaming packing and unpacking](#streaming-packing-and-unpacking)
  - [Mapping](#mapping)
    - [Default packing from Zig types to MessagePack](#default-packing-from-zig-types-to-messagepack)
    - [Default unpack from MessagePack to Zig types](#default-unpack-from-messagepack-to-zig-types)
    - [Custom packing](#custom-packing)
    - [Custom unpacking](#custom-unpacking)
<!--toc:end-->

A MessagePack library for Zig with no allocations.

## How to use

1. Run the following command to add this project as a dependency

   ```sh
   zig fetch --save git+https://github.com/uyha/mzg.git
   ```

1. In your `build.zig`, add the following

   ```zig
   const zimq = b.dependency("mzg", .{
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

## Example

### Streaming packing and unpacking

When there is multiple items in the message but the message is not an array
(amount of items is not indicated in the beginning), the following example shows
how to do it.

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    for ([_]Targets{
        .{ .position = .init(1000), .velocity = .init(50) },
        .{ .position = .init(2000), .velocity = .init(10) },
    }) |targets| {
        try mzg.pack(targets, buffer.writer(allocator));
    }
    // Inject stray byte
    try buffer.append(allocator, 1);

    std.debug.print("MessagPack bytes: {X:02}\n", .{buffer.items});

    var targets: std.ArrayListUnmanaged(Targets) = .empty;
    var size: usize = 0;
    while (size < buffer.items.len) {
        size += mzg.unpack(
            buffer.items[size..],
            try targets.addOne(allocator),
        ) catch {
            // Remove unpopulated item
            _ = targets.pop();
            break;
        };
    }
    std.debug.print("Length: {}\n", .{targets.items.len});
    for (targets.items) |*t| {
        std.debug.print("{}\n", .{t});
    }
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

### Custom packing

When an enum/union/struct has an `mzgPack` function with the signature being
either

```zig
pub fn mzgPack(self: *@This(), writer: anytype) !void
```

```zig
pub fn mzgPack(self: *@This(), options: mzg.PackOptions, writer: anytype) !void
```

The function will be called when the `mzg.pack` function is used.

### Custom unpacking

When an enum/union/struct has an `mzgUnpack` function with the signature being

```zig
pub fn mzgUnpack(self: @This(), buffer: []const u8) UnpackError!usize
```

The function will be called when the `mzg.unpack` function is used.
