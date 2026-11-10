`include "fixtures.vh"
/*  This file is part of JTPOPEYE.
    JTPOPEYE program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTPOPEYE program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTPOPEYE.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 12-3-2019 */

`timescale 1ns/1ps

// TPP2-VIDEO SCHEMATIC 1/3

module jtpopeye_buf(
    input               rst_n,
    input               clk,
    input               H0_cen,
    input               pxl_cen,

    input               ROHVS,
    input               ROHVCK,
    input               RV_n,

    input      [ 7:0]   H,
    input               HB,
    input      [ 7:0]   V,
    input               H2O,
    input      [28:0]   DO,

    output reg [ 8:0]   ROVI,
    output reg [17:0]   DJ
);

//reg ROVI_hc; // half carry
//reg [3:0] nc;
reg [2:0] adder_data;

always @(*) begin // do not latch
    ROVI =  { 1'b0, DO[15:8] } + { 1'b0, V[7:0] }
        + { 8'd0, RV_n ^ ROHVCK }; // carry in
    //{ ROVI_hc, nc } = 4'd15 + { 1'b0, ROVI[7:4] } + { 4'b0, ROVI[3] }; // 3T LS283
    adder_data = {3{DO[27]}} ^ ROVI[2:0];
end

reg [17:0] ram0_din, ram1_din;

wire [5:0] scan_addr = { H[7:3], H2O };
wire [5:0] wr_addr   = DO[7:2];

reg [5:0] ADR0, ADR1;
wire [17:0] DJ0, DJ1;
wire line_sel0 =  V[0]; // line_sel marks the line selected for output
wire line_sel1 = ~V[0];
// wire DJ_sel;
reg we0, we1;

// DO[15:8] - object's Y
// DO[ 7:0] - object's X, DO[7:3] used to address the object buffer

wire [8:0] objy   = DO[15:8];
`ifdef SIMULATION
wire [7:0] objx   = DO[ 7:0];
wire    objbank   = DO[28];
wire [2:0] objpal = DO[26:24];
wire    hflip     = DO[23];
wire    vflip     = DO[27];
wire [6:0] objid  = DO[22:16];
`endif

reg [7:0] inzone0;
reg [3:0] inzone1;
reg       inzone_b;

always @(*) begin
    inzone0 = objy + V;
    { inzone_b, inzone1 } = { 1'b0, inzone0[7:4] } + 5'hf + {4'h0, inzone0[3] };
end

wire we_cmp = H[0]==1'b0 && !inzone_b && !ROHVS;

always @(posedge clk) begin // do not clock gate or OBJ pixels will get shifted to the right
    ADR0 <= line_sel0 ? scan_addr : wr_addr;
    ADR1 <= line_sel1 ? scan_addr : wr_addr;
    // DJ_sel = line_sel ? ~(ROVI_hc | (ROHVS | ~H[0])) : 1'b1;
    `ifndef OBJTEST
    we0      <= line_sel0 ? (H[1:0]==2'b11 && !HB): we_cmp;
    we1      <= line_sel1 ? (H[1:0]==2'b11 && !HB): we_cmp;
    `else
    we0 <= 1'b0;
    we1 <= 1'b0;
    `endif
    ram0_din <= { DO[28], DO[26:24]&{3{~line_sel0}}, // ram0 uses V[0]
            DO[1:0], DO[23:21], DO[20:16],
            adder_data, DO[27] };
    // ram1 uses ~V[0]
    ram1_din <= {
            DO[28],     // obj ID MSB (or sprite bank as MAME calls it)
            DO[26:24]&{3{~line_sel1}}, // palette, (set to 0 to clear data after reading)
            DO[1:0],    // sub H
            DO[23],     // h flip
            DO[22:16],  // obj ID
            adder_data, // sub V
            DO[27] };   // v flip
end

// DJ[0] - object's Y LSB (interlaced)
// DJ[3:1] - object's Y (mod 8)
// { DJ[17], DJ[10:4] } - object ID
// DJ[16:14] - object's palette
// DJ[11] - hflip
// DJ[13:12] - count start

// 1M and 3M memories in schematic
wire [2:0] objy0, objy1;

jt2020_ram #(.aw(6), .dw(18),.simhexfile("objtest.hex")) u_ram0(
    .clk    ( clk            ),
    .cen    ( pxl_cen        ),
    .data   ( ram0_din       ),
    .addr   ( ADR0           ),
    .we     ( we0            ),
    .q      ( DJ0[17:0]      )
);

// 1P and 3P memories in schematic
jt2020_ram #(.aw(6), .dw(18),.simhexfile("objtest.hex")) u_ram1(
    .clk    ( clk            ),
    .cen    ( pxl_cen        ),
    .data   ( ram1_din       ),
    .addr   ( ADR1           ),
    .we     ( we1            ),
    .q      ( DJ1[17:0]      )
);
// 00
// 01 si
// 10 si
// 11 no
always @(posedge clk) if(pxl_cen)
    if( !H[0] ) DJ <= line_sel1 ? DJ1 : DJ0;

endmodule // jtpopeye_dma
