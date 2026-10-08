# LF-buffer BRAM keep mode

This simunit checks the `fb_keep` path in `jtframe_lfbuf_bram_ctrl`.

The test first writes a complete baseline line with `fb_keep=0`. It then writes
a sparse line with `fb_keep=1` and verifies that pixels equal to `LFBUF_CLR`
leave the existing BRAM frame-buffer contents unchanged, while non-blank pixels
are updated. A final sparse write with `fb_keep=0` verifies that the original
behavior still overwrites blank pixels.
