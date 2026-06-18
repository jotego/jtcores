# LF-buffer BRAM write data alignment

This simunit checks the handoff between `jtframe_lfbuf_line` and
`jtframe_lfbuf_bram_ctrl` during the BRAM write phase.

The test fills one completed line with a unique value per horizontal address,
then lets the BRAM controller copy that line from `fb_din` into its internal
storage. The stored line, and the later lineout refill, must carry
`pattern[x]` at each horizontal address. A one-cycle `fb_din` latency bug
appears as a stale first pixel and a line shifted by one entry.
