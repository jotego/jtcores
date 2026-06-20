# jtframe_dwnld backpressure test

Checks that `jtframe_dwnld` preserves a byte that arrives while a previous
SDRAM programming write is still waiting for `sdram_ack`.
