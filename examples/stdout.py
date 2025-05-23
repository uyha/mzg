# /// script
# dependencies = [
#   "msgpack",
# ]
# ///

import sys
import msgpack

sys.stdout.buffer.write(msgpack.packb({"name": "velocity", "value": 100}))
