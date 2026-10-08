# LF buffer write-line latch

This simunit checks that `jtframe_lfbuf_ddr_ctrl` writes a completed line to the `ln_v` value that was present when `ln_done` rose. The write can be delayed until a safe active-video slot; changes to live `ln_v` during that delay must not move the line to a different frame-buffer row.
