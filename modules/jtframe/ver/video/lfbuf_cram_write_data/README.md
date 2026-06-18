# LF-buffer CRAM write data alignment

This simunit checks the handoff between `jtframe_lfbuf_line` and
`jtframe_lfbuf_ctrl` during the CellRAM/PSRAM write phase.

The test fills one completed line with a unique value per horizontal address,
then lets the CRAM controller copy that line out through the PSRAM bus. The
local PSRAM model latches the address on `cr_advn`, waits through the initial
latency, and then accepts back-to-back write data whenever `cr_wait` is high.
The accepted write stream must carry `pattern[x]` at each burst position.
