# LF-buffer SRAM write data alignment

This simunit checks the handoff between `jtframe_lfbuf_line` and
`jtframe_lfbuf_sram_ctrl` during the SRAM write phase.

The test fills one completed line with a unique value per horizontal address,
then lets the SRAM controller copy that line out through `fb_din` /
`sram_data`. The SRAM write stream must carry `pattern[x]` when
`sram_addr[HW-1:0]` is `x`. A one-cycle `fb_din` latency bug appears as
`pattern[x-1]` and fails the test immediately.
