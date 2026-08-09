# LF-buffer BRAM 256-word storage wrap

This simunit checks the `jtframe_lfbuf_bram` storage-width split used by
256-pixel targets with a wider LF-buffer protocol.

The test instantiates the BRAM LF-buffer with `HW=9` and `JTFRAME_WIDTH=256`.
It establishes a 384-count line (`256` active + `128` blanking), writes a source
line that contains distinct values in addresses `0..511`, and verifies that the
internal BRAM row completes after 256 words. The reduced BRAM stores logical
addresses `0..254` directly and reserves the last physical word for logical
address `511`, which feeds the wrapped edge/prefetch slot. If the controller
writes 512 words through an 8-bit storage address, the second half of the source
line overwrites the first half and the test fails.
