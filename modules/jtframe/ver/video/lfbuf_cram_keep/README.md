# LF-buffer CRAM keep mode

This simunit checks `fb_keep` in the CellRAM/PSRAM LF-buffer controller.

The test writes a complete baseline line to the PSRAM model, then writes a
sparse line with `fb_keep=1`. Write bursts whose pixel equals `LFBUF_CLR` must
assert both byte masks through `cr_dsn`, leaving the previous PSRAM contents
unchanged. A final sparse write with `fb_keep=0` verifies that blank pixels are
still written in the original mode.
