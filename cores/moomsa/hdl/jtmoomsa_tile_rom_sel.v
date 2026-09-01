/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_tile_rom_sel(
    input  romcs,
    input  colcs,
    input  k056_rom_cs,
    input  cpu_we,
    output tile_cs,
    output rmrd
);

`ifdef MOO_JTSIM_NO_GFX
assign tile_cs = 1'b0;
assign rmrd    = 1'b0;
`else
assign tile_cs = colcs || (romcs && !cpu_we) || k056_rom_cs;
assign rmrd    = romcs || k056_rom_cs;
`endif

endmodule
