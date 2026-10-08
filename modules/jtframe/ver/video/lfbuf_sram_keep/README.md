# LF-buffer SRAM keep mode

This simunit checks `fb_keep` in the SRAM LF-buffer controller.

The test writes a baseline line in keep mode, toggles the frame bit, then writes
a sparse line with `fb_keep=1`. The SRAM row bank bit must remain fixed at bank
0 and blank pixels must leave `sram_we` inactive, preserving the previous
contents. A final sparse write with `fb_keep=0` verifies that the original mode
still writes blank pixels.
