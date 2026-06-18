# LF-buffer SDR write data boundary

This simunit checks the handoff between `jtframe_lfbuf_line` and
`jtframe_lfbuf_sdr_ctrl` during the SDR write phase.

The test fills one completed line with a unique value per horizontal address,
then lets the SDR controller copy that line through the SDRAM command/data
pins. A local SDR command monitor records every `CMD_WRITE` column and data
word. The write stream must contain one write for every X coordinate, including
the final pixel at `LINE_W-1`.
