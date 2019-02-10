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
    Date: 20-1-2019 */

// 1942 Object Data RAM

module jt1942_objram(
    input              rst,
    input              clk,
    input              cen6,    //  6 MHz
    input              cen3,    //  3 MHz
    // Timing
    input   [3:0]      pxlcnt,
    input   [4:0]      objcnt,
    input              SEATM_b,
    // CPU interface
    input   [7:0]      DB,
    input   [6:0]      AB,
    input              obj_cs,
    input              wr_n,
    // memory output
    output reg  [7:0]  objbuf_data0,
    output reg  [7:0]  objbuf_data1,
    output reg  [7:0]  objbuf_data2,
    output reg  [7:0]  objbuf_data3
);

wire [6:0] scan = { objcnt, pxlcnt[1:0] };
wire [6:0] addr = SEATM_b ? AB : scan;
wire we = SEATM_b && !wr_n && obj_cs;
wire [7:0] ram_data;

jtgng_ram #(.aw(7)) u_ram(
    .clk    ( clk         ),
    .cen    ( cen3        ),
    .data   ( DB          ),
    .addr   ( addr        ),
    .we     ( we          ),
    .q      ( ram_data    )
);

//`define OBJ_TEST

`ifndef OBJ_TEST
// Latches data output. It can be done without this, but
// I find this less prone to bugs
reg [31:0] collect;

always @(posedge clk) if(cen6) begin
    collect[31:0] <= {collect[23:0], ram_data };
    if( !SEATM_b && pxlcnt==4'd6 ) begin
        { objbuf_data2, objbuf_data3, objbuf_data0, objbuf_data1 } <= collect;
    end
end
`else
always @(posedge clk) if(cen6) 
if( !SEATM_b && pxlcnt==4'd6 ) case(scan[6:2])
    // 5'd0: {objbuf_data0,objbuf_data1,objbuf_data2,objbuf_data3} <= 32'hD2_46_61_20;
    // 5'd1: {objbuf_data0,objbuf_data1,objbuf_data2,objbuf_data3} <= 32'h11_04_98_c0;
    // 5'd2: {objbuf_data0,objbuf_data1,objbuf_data2,objbuf_data3} <= 32'h12_04_b0_c0;
    // 5'd3: {objbuf_data0,objbuf_data1,objbuf_data2,objbuf_data3} <= 32'h13_04_c8_c0;
    // 5'd4: {objbuf_data0,objbuf_data1,objbuf_data2,objbuf_data3} <= 32'he0_40_80_a0;
    // 5'd5: {objbuf_data0,objbuf_data1,objbuf_data2,objbuf_data3} <= 32'he1_40_b0_a0;
    // 5'd6: {objbuf_data0,objbuf_data1,objbuf_data2,objbuf_data3} <= 32'he4_40_80_80;
    //5'd7: {objbuf_data0,objbuf_data1,objbuf_data2,objbuf_data3} <= 32'h6c_a6_40_20;
    5'd8: {objbuf_data0,objbuf_data1,objbuf_data2,objbuf_data3} <= 32'h6C_A6_61_20;
    5'd9: {objbuf_data0,objbuf_data1,objbuf_data2,objbuf_data3} <= 32'h6C_00_00_20;
    default: {objbuf_data0,objbuf_data1,objbuf_data2,objbuf_data3} <= 32'h0;
endcase
`endif
endmodule // jtgng_objdraw