# jtframe_reset clk24 alignment

Checks that `game_rst` is released on the same clk24 phase whatever the length
of the reset request, for clk_rom at 48 MHz (clk24 = clk_rom/2) and at 96 MHz
(clk24 = clk_rom/4). A third instance has no running clk24 and must still
leave reset. Without the alignment, the clk24 and clk_rom logic of a game can
start with a different relative phase from one run to the next.

A fourth instance also gets `rfsh_safe`, which models the second half of the
SDRAM refresh period, and must only release `game_rst` while it is high.
