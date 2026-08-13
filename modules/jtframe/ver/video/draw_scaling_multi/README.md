# `jtframe_draw` multi-tile scaling

This simunit checks that `hz_keep` carries horizontal scaling across a four-tile
object. Each tile is 16 pixels wide and contains pens `0..15`; every output
address must be written exactly once. The overall output width must equal the
scaled 64-pixel source width.
