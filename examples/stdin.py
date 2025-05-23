# /// script
# dependencies = [
#   "msgpack",
# ]
# ///

import sys
import msgpack

print(msgpack.unpackb(sys.stdin.buffer.read()))
