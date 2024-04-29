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
    Date: 29-4-2024 */

module jts18_vdp(
    input              rst,
    input              clk,
    output             ed_clk,

    // Main CPU interface
    input       [23:1] main_addr,
    input       [15:0] main_dout,
    output      [15:0] main_din,
    input              main_rnw,
    input              main_asn,
    input       [ 1:0] main_dsn,
    output             dtackn,
    // Video output
    output             hs,
    output             vs,
    output      [ 7:0] red,
    output      [ 7:0] green,
    output      [ 7:0] blue
);

wire       ras1, cas1, we0, oe1, sc, se0, ad, dtack,
           vs_n;
wire [7:0] sd;
reg        rst_n;

assign dtackn = ~dtack;
assign vs     = ~vs_n;

assign RD =
    (~ym_RD_d ? ym_RD_o : RD_mem);

assign AD =
    (~ym_AD_d ? ym_AD_o : 8'h0) |
    (~vram1_AD_d ? vram1_AD_o : 8'h0) |
    ((ym_AD_d & vram1_AD_d) ? AD_mem : 8'h0);

always @(negedge clk) rst_n <= rst;

ym7101 u_vdp(
    .RESET      ( rst_n     ),
    .MCLK       ( clk       ),      // 48 MHz
    .EDCLK_i    ( 1'b0      ),
    .EDCLK_o    ( ed_clk    ),
    .EDCLK_d    (           ),
    // M68000
    .CA_i       ( main_addr ),
    .CA_o       (           ),
    .CA_d       (           ),
    .CD_i       ( main_dout ),
    .CD_o       ( main_din  ),
    .CD_d       (           ),
    .RW         ( main_rnw  ),
    .LDS        (main_dsn[0]),
    .UDS        (main_dsn[1]),
    .AS         ( main_asn  ),
    .IPL1_pull  (           ),
    .IPL2_pull  (           ),
    .DTACK_i    ( dtackn    ),
    .DTACK_pull ( dtack     ),
    // Z80 interface is disabled
    .BR_pull    (           ),
    .INT_pull   (           ),
    .MREQ       ( 1'b1      ),
    .BG         ( 1'b1      ),
    .IORQ       ( 1'b1      ),
    .M1         ( 1'b1      ),
    .RD         ( 1'b1      ),
    .WR         ( 1'b1      ),
    // VRAM
    .AD_o       ( ad        ),
    .AD_i       ( ad        ),
    .AD_d       (           ),
    .SD         ( sd        ),
    .SE1        (           ),
    .RAS1       ( ras1      ),
    .CAS1       ( cas1      ),
    .WE0        ( we0       ),      // shouldn't it be we1?
    .WE1        (           ),
    .OE1        ( oe1       ),
    .SE0        ( se0       ),
    .SC         ( sc        ),
    // configuration
    .SEL0       ( 1'b1      ),      // always use M68k
    .HL         ( 1'b1      ),
    .PAL        ( 1'b1      ),
    // other unconnected pins
    .RA         (           ),
    .RD_d       (           ),
    .RD_o       (           ),
    .RD_i       (           ),
    // video and sound outputs
    .HSYNC_i    ( 1'b1      ),
    .HSYNC_pull ( hs        ),
    .CSYNC_i    ( 1'b1      ),
    .CSYNC_pull (           ),
    .VSYNC      ( vs_n      ),
    .SOUND      (           ),
    .DAC_R      ( red       ),
    .DAC_G      ( green     ),
    .DAC_B      ( blue      )
);

vram u_vram(
    .MCLK       ( clk       ),
    .RAS        ( ras1      ),
    .CAS        ( cas1      ),
    .WE         ( we1       ),
    .OE         ( oe1       ),
    .SC         ( sc        ),
    .SE         ( se0       ),
    .AD         ( ad        ),
    .RD_i       ( ad        ),
    .RD_o       ( vram_AD_o ),
    .RD_d       ( vram_AD_d ),
    .SD_o       ( vram_SD_o ),
    .SD_d       ( vram_SD_d )
);

endmodule
