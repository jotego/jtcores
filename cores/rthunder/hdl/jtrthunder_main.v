/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-3-2025 */

module jtrthunder_main(
    input               rst, clk,
                        lvbl,

    output              tile_bank,
    output       [ 7:0] backcolor,

    output              mrom_cs,   srom_cs,   ram_cs,
    input               mrom_ok,   srom_ok,   ram_ok,
    input        [ 7:0] mrom_data, srom_data, ram_dout,

    input        [ 7:0] debug_bus,
    output       [ 7:0] st_dout
);
`ifndef NOMAIN

wire [15:0] maddr;
wire [ 7:0] mdout, sdout;
wire        mrnw, srnw, mint_n, sint_n;
wire        mscr0_cs, mscr1_cs, moram_cs, mmbank_cs, msbank_cs, mlatch0_cs, mlatch1_cs, bcolor_cs,
            sscr0_cs, sscr1_cs, soram_cs, smbank_cs, ssbank_cs, slatch0_cs, slatch1_cs;

assign st_dout   = 0;

jtframe_mmr_reg u_backcolor(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( mrnw      ),
    .din        ( mdout     ),
    .cs         ( bcolor_cs ),
    .dout       ( backcolor )
);

// address decoder for main CPU
jtcus47 u_cus47(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .lvbl       ( lvbl      ),
    .addr       ( maddr     ),
    .rnw        ( mrnw      ),
    .bank       ( tile_bank ),
    .scr0_cs    ( mscr0_cs  ),
    .scr1_cs    ( mscr1_cs  ),
    .latch0_cs  ( mlatch0_cs),
    .latch1_cs  ( mlatch1_cs),
    .latch2_cs  ( bcolor_cs ),
    .oram_cs    ( moram_cs  ),
    .mbank_cs   ( mmbank_cs ),
    .sbank_cs   ( msbank_cs ),
    .wdog_cs    (           ),
    .int_n      ( mint_n     )
);

// address decoder for sound CPU
jtcus41 u_cus41(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .lvbl       ( lvbl      ),
    .addr       ( saddr     ),
    .rnw        ( srnw      ),
    .scr0_cs    ( sscr0_cs  ),
    .scr1_cs    ( sscr1_cs  ),
    .latch0_cs  ( latch0_cs ),
    .latch1_cs  ( latch1_cs ),
    .oram_cs    ( soram_cs  ),
    .mbank_cs   ( smbank_cs ),
    .sbank_cs   ( ssbank_cs ),
    .wdog_cs    (           ),
    .int_n      ( int_n     )
);

mc6809i u_mcpu(
    .nRESET     ( rst_n     ),
    .clk        ( clk       ),
    .cen_E      ( main_E    ),
    .cen_Q      ( main_Q    ),
    .D          ( mdin      ),
    .DOut       ( mdout     ),
    .ADDR       ( maddr     ),
    .RnW        ( mrnw      ),
    // Interrupts
    .nIRQ       ( mint_n    ),
    .nFIRQ      ( 1'b1      ),
    .nNMI       ( 1'b1      ),
    .nHALT      ( 1'b1      ),
    // unused
    .AVMA       ( mavma     ),
    .BS         (           ),
    .BA         (           ),
    .BUSY       (           ),
    .LIC        (           ),
    .nDMABREQ   ( 1'b1      ),
    .OP         (           ),
    .RegData    (           )
);

mc6809i u_scpu(
    .nRESET     ( rst_n     ),
    .clk        ( clk       ),
    .cen_E      ( sub_E     ),
    .cen_Q      ( sub_Q     ),
    .D          ( sdin      ),
    .DOut       ( sdout     ),
    .ADDR       ( saddr     ),
    .RnW        ( srnw      ),
    // Interrupts
    .nIRQ       ( sint_n    ),
    .nFIRQ      ( 1'b1      ),
    .nNMI       ( 1'b1      ),
    .nHALT      ( 1'b1      ),
    // unused
    .AVMA       ( savma     ),
    .BS         (           ),
    .BA         (           ),
    .BUSY       (           ),
    .LIC        (           ),
    .nDMABREQ   ( 1'b1      ),
    .OP         (           ),
    .RegData    (           )
);
`else
// change for scene values:
assign tile_bank = 0;
assign backcolor = 0;
assign st_dout   = 0;
`endif
endmodule