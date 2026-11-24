# Deterministic row stride sequence test

This simunit exercises the controller's actual row-residue update logic at
heights 1, 3, 7, 223, 224, 511, and 512. It covers unit, default-like,
nondividing, and height-clamped strides, and checks every ordinal's selected
row. Each row uses the actual capture controller and line encoder with a
one-pixel active line, then releases the FIFO head through the controller's
command parser.

Run with `simunit.sh --run modules/jtframe/ver/video/capture_stride`.
