# Cross language packing and unpack via stdout and stdin

## Zig to Python

There are 2 files `stdout.zig` and `stdin.py` that can be used to demonstrate
serialization from Zig to Python. To run the example, you have to make sure that
your Python interpreter already has `msgpack` installed:

```sh
zig build mzg-example-stdout | python3 stdin.py
```

If you use `uv`, you can run

```sh
zig build mzg-example-stdout | uv run stdin.py
```

## Python to Zig

There are 2 files `stdout.py` and `stdin.zig` that can be used to demonstrate
serialization from Python to Zig. To run the example, you have to make sure that
your Python interpreter already has `msgpack` installed:

```sh
python3 stdin.py | zig build mzg-example-stdout
```

If you use `uv`, you can run

```sh
uv run stdin.py | zig build mzg-example-stdout
```
