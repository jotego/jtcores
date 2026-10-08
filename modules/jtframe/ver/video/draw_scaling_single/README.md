# `jtframe_draw` single-tile scaling

This simunit uses the Run and Gun drawer configuration (`ZW=12`, `ZI=6`,
`ZENLARGE=1`) and a deterministic 16-pixel tile. Pixel `n` has pen value `n`.
It verifies the enlarged-sprite accumulator invariant:

```text
output length = ceil(16 * HZONE / hzoom)
output pen[i] = floor(i * hzoom / HZONE)
```

Thus every scale exactly representable by this inverse binary fixed-point
format produces its exact pixel count. For example, `hzoom=0x20`, `0x10`, and
`0x08` produce 2x, 4x, and 8x. Nominal factors such as 3x and 1.25x are also
exercised using the nearest encodable values, but their expected lengths follow
the formula above because `0x40/3` and `0x40*4/5` are not integers.

The test includes the nominal 1.25x, 1.5x, and 2.5x cases to cover fractional
enlargement and its quantisation.
