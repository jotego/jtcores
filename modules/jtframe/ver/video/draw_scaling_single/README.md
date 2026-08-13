# `jtframe_draw` single-tile scaling

This simunit uses the Run and Gun drawer configuration (`ZW=12`, `ZI=6`,
`ZENLARGE=1`) and a deterministic 16-pixel tile. Pixel `n` has pen value `n`,
so integer enlargement must repeat every pen exactly the requested number of
times and produce the exact scaled width.

The test also checks fractional factors whose 16-pixel source width has an
integer destination width: 1.25x, 1.5x, and 2.5x.
