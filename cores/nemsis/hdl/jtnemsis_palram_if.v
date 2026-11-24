// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-only
// Date: 2026-11-08
// Palette RAM CPU byte-lane adapter.
`default_nettype none

module jtnemsis_palram_if(
    input      [11:1] cpu_addr,
    input      [15:0] cpu_din,
    input             cs_n,
    input             rnw,
    input             uds_n,
    input             lds_n,
    output     [11:1] pal_addr,
    output     [15:0] pal_din,
    output     [ 1:0] pal_we
);

assign pal_addr = cpu_addr;
assign pal_din  = cpu_din;
assign pal_we   = { &{ ~cs_n, ~rnw, ~uds_n },
                    &{ ~cs_n, ~rnw, ~lds_n } };

endmodule

`default_nettype wire
