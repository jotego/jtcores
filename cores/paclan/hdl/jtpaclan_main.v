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
    Date: 18-5-2025 */

module jtpaclan_main(
    input               rst, clk,
                        cen_E, cen_Q, lvbl,

    output              flip, srst,

    output       [ 1:0] palbank,
    output       [ 7:0] cpu_dout,
    output       [ 1:0] scr0_we, scr1_we, oram_we,
    output              rnw,

    output       [16:0] rom_addr,
    input        [ 7:0] rom_data,
    output              rom_cs, bus_busy,
    input               rom_ok,

    output       [ 8:0] scr0_pos,  scr1_pos,
    input        [15:0] scr0_dout, scr1_dout, oram_dout,

    // CUS30
    output              c30_cs,
    input        [ 7:0] c30_dout,

    // IOCTL dump
    input        [ 1:0] ioctl_addr,
    output       [ 7:0] ioctl_din,

    input        [ 7:0] debug_bus,
    output       [ 7:0] st_dout
);
`ifndef NOMAIN
wire [15:0] cpu_addr;
wire [ 2:0] bank,nc;
wire [ 7:0] cpu_din;
wire        int_n, avma,
            main_E, main_Q, basel_cs, ok_dly,
            scr0_cs, scr1_cs, oram_cs, scr0pos_cs, scr1pos_cs,
            banked_cs, wdog, rst_n;

assign st_dout  = {wdog,4'd0,flip,palbank};
assign rom_addr = banked_cs ? {1'b1,bank, cpu_addr[12:0]} : {1'b0,cpu_addr};
assign bus_busy = rom_cs & ~ok_dly;
assign scr0_we  = {2{scr0_cs & ~rnw}} & {cpu_addr[0],~cpu_addr[0]};
assign scr1_we  = {2{scr1_cs & ~rnw}} & {cpu_addr[0],~cpu_addr[0]};
assign oram_we  = {2{oram_cs & ~rnw}} & {cpu_addr[0],~cpu_addr[0]};

jtframe_mmr_reg #(.W(9)) u_scr0pos(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( rnw       ),
    .din        ( {cpu_addr[0],cpu_dout}  ),
    .cs         ( scr0pos_cs),
    .dout       ( scr0_pos  )
);

jtframe_mmr_reg #(.W(9)) u_scr1pos(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( rnw       ),
    .din        ( {cpu_addr[0],cpu_dout}  ),
    .cs         ( scr1pos_cs),
    .dout       ( scr1_pos  )
);

jtframe_mmr_reg u_pal_rombank(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( rnw       ),
    .din        ( cpu_dout  ),
    .cs         ( basel_cs  ),
    .dout       ( {nc,palbank,bank}   )
);

jtframe_watchdog #(.INVERT(1))u_wdog( rst, clk, lvbl, wdog, rst_n);

// address decoder for main CPU
jtcus34 u_cus34(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .lvbl       ( lvbl      ),
    .flip       ( flip      ),
    .srst       ( srst      ),

    .addr       ( cpu_addr  ),
    .rnw        ( rnw       ),

    .scr0pos_cs ( scr0pos_cs),
    .scr1pos_cs ( scr1pos_cs),

    .scr0_cs    ( scr0_cs   ),
    .scr1_cs    ( scr1_cs   ),
    .oram_cs    ( oram_cs   ),
    .rom_cs     ( rom_cs    ),
    .c30_cs     ( c30_cs    ),

    .basel_cs   ( basel_cs  ),
    .banked_cs  ( banked_cs ),
    .wdog_cs    ( wdog      ),
    .int_n      ( int_n     )
);

jtpaclan_busmux u_busmux(
    .clk        ( clk       ),
    .addr0      (cpu_addr[0]),
    .rom_ok     ( rom_ok    ),
    .ok_dly     ( ok_dly    ),

    .scr0_cs    ( scr0_cs   ),
    .scr1_cs    ( scr1_cs   ),
    .oram_cs    ( oram_cs   ),
    .c30_cs     ( c30_cs    ),
    .rom_cs     ( rom_cs    ),

    .scr0_dout  ( scr0_dout ),
    .scr1_dout  ( scr1_dout ),
    .oram_dout  ( oram_dout ),
    .c30_dout   ( c30_dout  ),
    .rom_data   ( rom_data  ),

    .muxed      ( cpu_din   )
);

mc6809i u_cpu(
    .nRESET     ( rst_n     ),
    .clk        ( clk       ),
    .cen_E      ( cen_E     ),
    .cen_Q      ( cen_Q     ),
    .D          ( cpu_din   ),
    .DOut       ( cpu_dout  ),
    .ADDR       ( cpu_addr  ),
    .RnW        ( rnw       ),
    // Interrupts
    .nIRQ       ( int_n     ),  // verified on PCB
    .nFIRQ      ( 1'b1      ),
    .nNMI       ( 1'b1      ),
    .nHALT      ( 1'b1      ),
    // unused
    .AVMA       ( avma      ),
    .BS         (           ),
    .BA         (           ),
    .BUSY       (           ),
    .LIC        (           ),
    .nDMABREQ   ( 1'b1      ),
    .OP         (           ),
    .RegData    (           )
);
`else
    assign srst=0,
    cpu_dout=0,
    scr0_we=0, scr1_we=0, oram_we=0,rnw=1,rom_addr=0,rom_cs=0, bus_busy=0,
    c30_cs=0,st_dout=0;
`endif
jtframe_simdumper #(.DW(21)) dumper(
    .clk        ( clk           ),
    .rst        ( rst           ),
    .set_data   (               ),
    .data       ( {flip,palbank,scr1_pos,scr0_pos} ),
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( ioctl_din     )
);

endmodule
