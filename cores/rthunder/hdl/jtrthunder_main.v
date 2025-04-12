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
                        cen_main, cen_sub,
                        lvbl, sndext_en, nocpu2,

    output              tile_bank, latch0_cs, latch1_cs, bsel, dmaon, ommr_cs,
    output       [ 7:0] backcolor,

    output              mrom_cs,   srom_cs, ext_cs, bus_busy,
    input               mrom_ok,   srom_ok, ext_ok,
    output       [17:0] ext_addr,
    output       [15:0] mrom_addr, srom_addr,
    output       [12:0] baddr,
    output       [ 7:0] bdout,
    output       [ 1:0] scr0_we, scr1_we, oram_we,
    output              brnw,
    input        [ 7:0] mrom_data, srom_data, ext_data,
    input        [15:0] scr0_dout, scr1_dout, oram_dout,

    // CUS30
    output              mrnw, mc30_cs,
    input        [ 7:0] c30_dout,
    output       [ 7:0] mdout,
    output       [15:0] maddr,

    input        [ 7:0] debug_bus,
    output       [ 7:0] st_dout
);
`ifndef NOMAIN
wire [15:0] saddr;
wire [ 7:0] sdout, bdin;
wire [ 4:0] mbank_ext;
wire [ 1:0] mbank, sbank;
wire [ 7:0] mdin,  sdin;
wire        srnw, mint_n, sint_n,   mavma,     savma,
            main_E, main_Q, sub_E, sub_Q,
            mscr0_cs, mscr1_cs, moram_cs, mmbank_cs, msbank_cs, mlatch0_cs, mlatch1_cs, bcolor_cs,
            sscr0_cs, sscr1_cs, soram_cs, smbank_cs, ssbank_cs, slatch0_cs, slatch1_cs,
            mbanked_cs, sbanked_cs, c115_cs,
            mwdog, swdog, srst_n, mrst_n;

assign main_E = cen_main;
assign main_Q = cen_sub;
assign sub_E  = cen_sub;
assign sub_Q  = cen_main;

assign st_dout   = {6'd0,~swdog,~mwdog};
assign mrom_addr = mbanked_cs ? {1'b0,mbank, maddr[12:0]} : maddr;
assign srom_addr = sbanked_cs ? {1'b0,sbank, saddr[12:0]} : saddr;
assign ext_addr  = {mbank_ext,maddr[12:0]};
assign ext_cs    = mbanked_cs & sndext_en;
assign bus_busy  = |{mrom_cs&~mrom_ok, srom_cs&~srom_ok, ext_cs&~ext_ok};

jtframe_mmr_reg u_backcolor(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( mrnw      ),
    .din        ( mdout     ),
    .cs         ( bcolor_cs ),
    .dout       ( backcolor )
);

jtcus115 u_cus115(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cs         ( c115_cs   ),
    .addr       ( maddr     ),
    .din        ( mdout     ),
    .banksel    ( mbank_ext )
);

jtrthunder_busmux u_busmux(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_main   ( cen_main  ),
    .cen_sub    ( cen_sub   ),

    .mavma      ( mavma     ),
    .savma      ( savma     ),
    .bsel       ( bsel      ),
    .dmaon      ( dmaon     ),
    .ommr_cs    ( ommr_cs   ),

    .mc30_cs    ( mc30_cs   ),
    .mrom_cs    ( mrom_cs   ),
    .srom_cs    ( srom_cs   ),
    .mscr0_cs   ( mscr0_cs  ),
    .sscr0_cs   ( sscr0_cs  ),
    .mscr1_cs   ( mscr1_cs  ),
    .sscr1_cs   ( sscr1_cs  ),
    .mmbank_cs  ( mmbank_cs ),
    .msbank_cs  ( msbank_cs ),
    .smbank_cs  ( smbank_cs ),
    .ssbank_cs  ( ssbank_cs ),
    .moram_cs   ( moram_cs  ),
    .soram_cs   ( soram_cs  ),
    .mlatch0_cs ( mlatch0_cs),
    .mlatch1_cs ( mlatch1_cs),
    .slatch0_cs ( slatch0_cs),
    .slatch1_cs ( slatch1_cs),
    .ext_cs     ( ext_cs    ),
    // address
    .maddr      ( maddr     ),
    .saddr      ( saddr     ),
    .mrnw       ( mrnw      ),
    .srnw       ( srnw      ),
    // banking registers
    .mbank      ( mbank     ),
    .sbank      ( sbank     ),
    // data buses
    .mdout      ( mdout     ),
    .sdout      ( sdout     ),
    .mrom_data  ( mrom_data ),
    .ext_data   ( ext_data  ),
    .srom_data  ( srom_data ),
    .scr0_dout  ( scr0_dout ),
    .scr1_dout  ( scr1_dout ),
    .oram_dout  ( oram_dout ),
    .c30_dout   ( c30_dout  ),
    // multiplexed
    .latch0_cs  ( latch0_cs ),
    .latch1_cs  ( latch1_cs ),

    .oram_we    ( oram_we   ),
    .scr0_we    ( scr0_we   ),
    .scr1_we    ( scr1_we   ),

    .baddr      ( baddr     ),
    .brnw       ( brnw      ),
    .bdout      ( bdout     ),

    .mdin       ( mdin      ),
    .sdin       ( sdin      )
);

reg srst;

always @(posedge clk) srst <= rst | nocpu2;

jtframe_watchdog #(.INVERT(1))u_wdog_main( rst, clk, lvbl, mwdog, mrst_n);
jtframe_watchdog #(.INVERT(1))u_wdog_sub (srst, clk, lvbl, swdog, srst_n);

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
    .rom_cs     ( mrom_cs   ),
    .banked_cs  (mbanked_cs ),
    .snd_cs     ( mc30_cs   ),
    .c115_cs    ( c115_cs   ),
    .wdog_cs    ( mwdog     ),
    .int_n      ( mint_n    )
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
    .latch0_cs  ( slatch0_cs),
    .latch1_cs  ( slatch1_cs),
    .oram_cs    ( soram_cs  ),
    .mbank_cs   ( smbank_cs ),
    .sbank_cs   ( ssbank_cs ),
    .wdog_cs    ( swdog     ),
    .rom_cs     ( srom_cs   ),
    .banked_cs  (sbanked_cs ),
    .int_n      ( sint_n    )
);

mc6809i u_mcpu(
    .nRESET     ( mrst_n    ),
    .clk        ( clk       ),
    .cen_E      ( main_E    ),
    .cen_Q      ( main_Q    ),
    .D          ( mdin      ),
    .DOut       ( mdout     ),
    .ADDR       ( maddr     ),
    .RnW        ( mrnw      ),
    // Interrupts
    .nIRQ       ( mint_n    ),  // verified on PCB
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
    .nRESET     ( srst_n    ),
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
assign latch0_cs = 0, latch1_cs = 0, bsel = 0,
       mrom_cs   = 0, srom_cs   = 0, ext_cs = 0, bus_busy = 0,
       ext_addr  = 0, mrom_addr = 0, srom_addr = 0, baddr = 0, bdout = 0,
       scr0_we   = 0, scr1_we   = 0, oram_we   = 0, brnw  = 0,
       mrnw      = 0, mc30_cs   = 0, mdout     = 0, maddr = 0, st_dout = 0,
       dmaon     = lvbl,
       ommr_cs   = 0;
`endif
endmodule