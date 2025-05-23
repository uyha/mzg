# Cross language packing and unpack via stdout and stdin

There are 2 files `stdout.zig` and `stdin.py` that can be used to demonstrate
serialization cross languages. To run the example, you have to make sure that
your Python interpreter already has `msgpack` installed:

```sh
zig build mzg-example-stdout | python3 stdin.py
```

If you use `uv`, you can run

```sh
zig build mzg-example-stdout | uv run stdin.py
```
