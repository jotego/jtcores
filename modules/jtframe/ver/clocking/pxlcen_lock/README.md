# jtframe_pxlcen clk24 lock

Two `jtframe_pxlcen` instances start counting at different times, as happens
when the FPGA configuration and the PLL lock do not have a fixed timing. Once
`ph24` toggles, both must produce `pxl_cen` on the same clk24
phase. The video timer then starts every frame on the same clk24 phase, and
so does the game reset release that follows CAB START. This only holds when
the pixel period is a multiple of the clk24 period (6 and 8 MHz pixels), not
for 16 MHz pixels at 96 MHz.
