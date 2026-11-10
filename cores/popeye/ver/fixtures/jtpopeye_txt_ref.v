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

module jtpopeye_txt(
    input               rst_n,
    input               clk,
    input               pxl_cen,
    input               cpu_cen,
    input               pause,

    input      [12:0]   AD,
    input      [ 7:0]   DD,
    input      [ 7:0]   H,
    input      [ 7:0]   V,
    input               HB,
    input               VB,
    input               RV, // flip
    input               CSV,
    input               MEMWRO,

    // PROM
    input       [10:0]  prog_addr,
    input               prom_5n_we,
    input       [ 7:0]  prom_din,

    output  reg [ 3:0]  TXTC,
    output  reg         TXTV
);


reg  [3:0] txtc, txtc0;
wire [10:0] rom_addr;
reg  [ 9:0] ram_addr;

assign rom_addr[2:0] = V[2:0];

wire we = CSV & MEMWRO;
reg wev, wec;

wire [9:0] scan = { V[7:3], H[7:3] };
reg [7:0] din;
always @(posedge clk) begin
    ram_addr <= CSV ? AD[9:0] : scan;
    wev      <= we && AD[11:10]==2'b00;
    wec      <= we && AD[11:10]==2'b01; // colour
    din      <= DD;
end

// block-id in rom_addr MSB
// ram_addr: scans the screen
// H[7:3] -> 32 tiles, 8-pixel wide
// V[7:3] -> 32 tiles, 8-pixel height
// Screen size 32x32x8x8 = 256x256
jt2020_ram #(.aw(10), .dw(8)) u_ram_5pr(
    .clk    ( clk            ),
    .cen    ( cpu_cen        ),
    .data   ( din            ),
    .addr   ( ram_addr       ),
    .we     ( wev            ),
    .q      ( rom_addr[10:3] )
);

wire [7:0] pause_data;

jt2020_ram #(.aw(10), .dw(8),.synfile("msg.hex"),.simfile("msg.bin")) u_ram_pause(
    .clk    ( clk            ),
    .cen    ( cpu_cen        ),
    .data   ( 8'h00          ),
    .addr   ( scan           ),
    .we     ( 1'b0           ),
    .q      ( pause_data     )
);

wire [3:0] pre_txtc;
always @(posedge clk) if(pxl_cen) begin
    txtc <= pre_txtc;
end

// Colour, same data for 8 pixels
jt2020_ram #(.aw(10), .dw(4)) u_ram_5s(
    .clk    ( clk            ),
    .cen    ( cpu_cen        ),
    .data   ( din[3:0]       ),
    .addr   ( ram_addr       ),
    .we     ( wec            ),
    .q      ( pre_txtc       )
);

///////////////////////////
// Character ROM

wire [7:0] txtv;
reg [10:0] rom_addr_mux;

always @(posedge clk)
    rom_addr_mux <= pause ? {pause_data, V[2:0] } : rom_addr;

jt2020_prom #(.aw(11),.dw(8),.simfile(`CHARROM),
    .offset(12'h800)
) u_prom_5n(
    .clk    ( clk               ),
    .cen    ( pxl_cen           ),
    .data   ( prom_din          ),
    .rd_addr( rom_addr_mux      ),
    .wr_addr( prog_addr[10:0]   ),
    .we     ( prom_5n_we        ),
    .q      ( txtv              )
);

reg [7:0] txtv0;

always @(posedge clk) if(pxl_cen) begin
    if( H[2:0]==3'd7 && !HB) begin // TXTSHIFT / TXTCL signals
        txtv0 <= txtv;
        txtc0 <= pause ? 4'd0 : txtc; // 0 GREEN, 1 BLUE
    end
    else txtv0 <= RV ? { txtv0[6:0], 1'b0 } : { 1'b0, txtv0[7:1] };
    if( VB ) txtv0 <= 8'b0;
end

// latch output signals (without pixel CEN)
always @(posedge clk) begin
    TXTV <= ~(RV ? txtv0[7] : txtv0[0]);
    TXTC <= txtc0;
end

endmodule // jtpopeye_txt
