/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 19-2-2019 */

// 1943 Scroll Generation
// Schematics pages 8/15...

`timescale 1ns/1ps

module jt1943_scroll #( parameter
    HOFFSET         = 9'd5,
    ROM_AW          = 17,
    SIMFILE_MSB     = "", 
    SIMFILE_LSB     = "",
    AS8MASK         = 1'b1,
    PALETTE         = 1
)(
    input                rst,
    input                clk,  // >12 MHz
    input                cen6  /* synthesis direct_enable = 1 */,    //  6 MHz
    input                cen3,
    input         [ 7:0] V128, // V128-V1
    input         [ 8:0] H, // H256-H1
    input                LVBL,
    input                LHBL,

    input         [ 1:0] scrposh_cs,
    input         [ 7:0] vpos,
    input                SCxON,
    input                flip,
    input         [ 7:0] din,
    input                wr_n,
    input                pause,
    // Palette PROMs D1, D2
    input     [7:0]      prog_addr,
    input                prom_hi_we,
    input                prom_lo_we,
    input     [3:0]      prom_din,

    // Map ROM
    output   reg  [13:0] map_addr,
    input         [15:0] map_data,
    // Gfx ROM
    output  [ROM_AW-1:0] scr_addr,
    input         [15:0] scrom_data,
    output        [ 5:0] scr_pxl
);


// H goes from 80h to 1FFh
wire [8:0] Hfix_prev = H+HOFFSET;
wire [8:0] Hfix = !Hfix_prev[8] && H[8] ? Hfix_prev|9'h80 : Hfix_prev; // Corrects pixel output   offset

reg  [ 4:0] HS;
reg  [ 7:0] VF, SV, SH, PIC, PIC2,SH2;
wire [ 7:0] V128sh;
wire [ 7:0] HF = {8{flip}}^Hfix[7:0]; // SCHF2_1-8
reg  [15:0] hpos, SP=16'd0; // called "SP" on the schematics

wire H7 = (~Hfix[8] & (~flip ^ HF[6])) ^HF[7];
wire [9:0] SCHF = { HF[6]&~Hfix[8], ~Hfix[8], H7, HF[6:0] }; // SCHF30~21

// Because we process the signal a bit ahead of time
// (exactly HOFFSET pixels ahead of time), this creates
// an unbalance between the vertical line counter change
// and the current output   at the end of each line. It wasn't
// noticeable in 1943, but it can be seen in GunSmoke
// In order to avoid it, the V counter must be delayed by the same
// HOFFSET amount
jtgng_sh #(.width(8), .stages(HOFFSET) ) u_vsh
(
    .clk    ( clk     ),
    .clk_en ( cen6    ),
    .din    ( V128    ),
    .drop   ( V128sh  )
);

always @(*) begin
    VF = {8{flip}}^V128sh;
    SV = VF + vpos;
    {PIC, SH }  = SP + { {6{SCHF[9]}},SCHF };
    {PIC2, SH2 }  = hpos + { {6{SCHF[9]}},SCHF };
end

reg [4:0] SVmap; // SV latched at the time the map_addr is set

always @(posedge clk) if(cen6) begin
    // always update the map at the same pixel count
    if( SH[2:0]==3'd7 ) begin
        SP <= hpos;
        HS[4:3] <= SH2[4:3];
        map_addr <= { PIC2, SH2[7:6], SV[7:5], SH2[5] }; // SH[5] is LSB
            // in order to optimize cache use
        SVmap <= SV[4:0];
    end
    HS[2:0] <= SH[2:0] ^ {3{flip}};
end

`ifndef TESTSCR1
always @(posedge clk)
    if( rst ) begin
        hpos <= 16'd0;
    end else if(cen6) begin // same cen as main CPU
        if( scrposh_cs[1] && !wr_n ) hpos[15:8] <= din;
        if( scrposh_cs[0] && !wr_n ) hpos[ 7:0] <= din;
    end
`else
    initial hpos <= 'h100;
    always @(negedge LVBL)
        hpos <= hpos + 'h1;
`endif

wire [7:0] dout_high = map_data[ 7:0];
wire [7:0] dout_low  = map_data[15:8];

jtgng_tile4 #(
    .AS8MASK        ( AS8MASK       ),
    .PALETTE        ( PALETTE       ),
    .ROM_AW         ( ROM_AW        ),
    .SIMFILE_LSB    ( SIMFILE_LSB   ),
    .SIMFILE_MSB    ( SIMFILE_MSB   ) )
u_tile4(
    .clk        (  clk          ),
    .cen6       (  cen6         ),
    .HS         (  HS           ),
    .SV         (  SVmap        ),
    .attr       (  dout_high    ),
    .id         (  dout_low     ),
    .SCxON      ( SCxON         ),
    .flip       ( flip          ),
    // Palette PROMs
    .prog_addr  ( prog_addr     ),
    .prom_hi_we ( prom_hi_we    ),
    .prom_lo_we ( prom_lo_we    ),
    .prom_din   ( prom_din      ),
    // Gfx ROM
    .scr_addr   ( scr_addr      ),
    .rom_data   ( scrom_data    ),
    .scr_pxl    ( scr_pxl       )
);

endmodule