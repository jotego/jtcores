`include "fixtures.vh"
/*  This file is part of JTPOPEYE.
    JTPOPEYE program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTPOPEYE program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR AD PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTPOPEYE.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 12-3-2019 */

`timescale 1ns/1ps

// 2^6 = 64 horizontal x4 units
// 2^6 = 64 vertical   x4 units
// The screen is divided in two halves: top and bottom
// the nibbles of each memory separate these two halves

module jtpopeye_bck(
    input               rst_n,
    input               clk,
    input               pxl_cen,
    input               cpu_cen,

    // CPU interface
    input               CSBW_n,
    input               DWRBK,

    input               ROHVCK,
    input      [12:0]   AD,
    input      [ 8:0]   ROVI,
    input      [28:0]   DO,
    input      [ 7:0]   DD,
    output reg [ 3:0]   BAKC
);

reg [7:0] ROH;  // 74161. 7N/7M video sheet 3/3
reg [8:1] ROVl;

// 74161 x 2
always @(posedge clk) begin
    if(!ROHVCK) begin
        ROH  <= DO[7:0];
    end else if(pxl_cen) begin
        ROH <= ROH+8'd1;
    end
end

// 74273
reg ROHVCKl;
wire posedge_ROHVCK = ROHVCK && !ROHVCKl;
wire negedge_ROHVCK = ROHVCK && !ROHVCKl;
always @(posedge clk) ROHVCKl <= ROHVCK;

always @(posedge clk) begin
    if(!CSBW_n) begin
        ROVl <= 8'd0;
    end else
    // this is a posedge on schematics but if I do that I'll sample wrong data
    if( negedge_ROHVCK ) begin
        ROVl <= {~ROVI[8], ROVI[7:1] };
    end
end


reg [11:0] ram_addr;
wire [7:0] ram_dout;
// reg nibble_sel;
//
// always @(*) begin
//     nibble_sel = !CSBW_n ? !AD[12] : ROVl[7];
// end

always @(posedge clk) if(pxl_cen) begin : ROH_edge
    reg ROH_last;
    ROH_last <= ROH[1:0] == 2'b11;
    if( !ROH_last && ROH[1:0]==2'b11 && CSBW_n)
        BAKC <= !ROVl[7] ? ram_dout[3:0] : ram_dout[7:4];
end

reg [7:0] ram_din;
reg       msb_we, lsb_we;

always @(posedge clk or negedge rst_n) begin: ram_ports
    reg DWRBK_last;
    if( !rst_n ) begin
        {msb_we, lsb_we}  <= 2'b0;
        DWRBK_last <= 1'b0;
    end else begin
        DWRBK_last <= DWRBK;
        if( (DWRBK && !DWRBK_last) && !CSBW_n ) begin
            // set RAM address for reading
            {msb_we, lsb_we} <= !AD[12] ? 2'b01 : 2'b10;
            ram_addr   <= AD[11:0];
        end else begin
            msb_we <= 1'b0;
            lsb_we <= 1'b0;
            ram_addr <= ROVl[8] ? 12'd0 : {ROVl[6:1],ROH[7:2]};
        end
    end
end

jt2020_ram #(.aw(12), .dw(4)) u_msb(
    .clk    ( clk            ),
    .cen    ( 1'b1           ),
    .data   ( DD[3:0]        ),
    .addr   ( ram_addr       ),
    .we     ( msb_we         ),
    .q      ( ram_dout[7:4]  )
);

jt2020_ram #(.aw(12), .dw(4)) u_lsb(
    .clk    ( clk            ),
    .cen    ( 1'b1           ),
    .data   ( DD[3:0]        ),
    .addr   ( ram_addr       ),
    .we     ( lsb_we         ),
    .q      ( ram_dout[3:0]  )
);


endmodule // jtpopeye_bak
