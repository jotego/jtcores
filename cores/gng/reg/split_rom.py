#!/usr/bin/env python3
"""Split the assembled binary ($6000-$FFFF) into gg3.bin and gg4.bin."""
import sys, os

builddir = sys.argv[1] if len(sys.argv) > 1 else "build"
data = open(os.path.join(builddir, "reg_test.bin"), "rb").read()

# Binary covers $6000-$FFFF = 40960 bytes
# gg4.bin = $4000-$7FFF (16 KB): first $2000 = $FF pad, next $2000 = our $6000-$7FFF
gg4 = b'\xff' * 0x2000 + data[0:0x2000]
open(os.path.join(builddir, "gg4.bin"), "wb").write(gg4)

# gg3.bin = $8000-$FFFF (32 KB): remaining bytes
gg3 = data[0x2000:]
open(os.path.join(builddir, "gg3.bin"), "wb").write(gg3)

print(f"    gg4.bin: {len(gg4)} bytes, gg3.bin: {len(gg3)} bytes")
