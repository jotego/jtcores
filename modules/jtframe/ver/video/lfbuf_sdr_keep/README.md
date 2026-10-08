# LF-buffer SDR keep mode

This simunit checks `fb_keep` in the SDR SDRAM LF-buffer controller.

The test writes a baseline line in keep mode, toggles the frame bit, then writes
a sparse line with `fb_keep=1`. The SDRAM row bank bit must remain fixed at bank
0 and blank pixels must assert both byte masks through `SDRAM_DQML/DQMH`,
leaving the previous contents unchanged. A final sparse write with `fb_keep=0`
verifies that the original mode still writes blank pixels.
