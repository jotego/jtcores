/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 14-9-2026 */

// TMS320C10 DSP, using the IKA32010 core. The program ROM is external.
// cen is the CLKIN enable and must not be active on consecutive clocks, which
// is what syn/cpu/ika32010/timing.sdc relies on.
// int_n is edge triggered and sampled on the DSP's own clock, so it is not
// seen while hold is high.

module jtframe_tms32010(
    input             rst,
    input             clk,
    input             cen,
    input             hold,

    input             int_n,
    input             bio_n,

    output     [11:0] rom_addr,
    input      [15:0] rom_data,

    output     [ 2:0] port,
    input      [15:0] din,
    output     [15:0] dout,
    output            wr,       // OUT, dout valid; one cen long
    output            rd        // IN, din is latched while this is high
);

wire [11:0] aout;
wire        den_n, we_n, ncen;

assign rom_addr = aout;
assign port     = aout[2:0];
assign wr       = ~we_n;
assign rd       = ~den_n & ncen;

// IKA32010 clears its clock divider only on a clock enable
IKA32010 u_dsp(
    .i_EMUCLK       ( clk                       ),
    .i_CLKIN_PCEN   ( cen & (~hold | rst)       ),
    .o_CLKOUT       (                           ),
    .o_CLKOUT_PCEN  (                           ),
    .o_CLKOUT_NCEN  ( ncen                      ),
    .i_RS_n         ( ~rst                      ),
    .o_MEN_n        (                           ),
    .o_DEN_n        ( den_n                     ),
    .o_WE_n         ( we_n                      ),
    .o_AOUT         ( aout                      ),
    .i_DIN          ( den_n ? rom_data : din    ),
    .o_DOUT         ( dout                      ),
    .o_DOUT_OE      (                           ),
    .i_BIO_n        ( bio_n                     ),
    .i_INT_n        ( int_n                     )
);

endmodule
