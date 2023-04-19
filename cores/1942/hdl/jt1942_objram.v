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
    Date: 20-1-2019 */

// 1942 Object Data RAM


module jt1942_objram(
    input              rst,
    input              clk,
    (*direct_enable*) input cpu_cen,    //  6 MHz
    // Timing
    input   [3:0]      pxlcnt,
    input   [4:0]      objcnt,
    input   [3:0]      bufcnt,
    input              LVBL,
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

reg [7:0] cpu_data;
reg [6:0] cpu_AB;
reg       cpu_we;

always @(posedge clk) if( cpu_cen ) begin
    cpu_we <= 1'b0;
    if(!wr_n && obj_cs) begin
        cpu_data <= DB;
        cpu_AB   <= AB;
        cpu_we   <= !LVBL;
    end
end

wire [6:0] scan = { objcnt, bufcnt[2:1] };
wire [7:0] ram_data;

jtframe_dual_ram #(.AW(7),.SIMFILE("obj.bin")/*,.SYNFILE("objtest.hex")*/) u_ram(
    // Scan
    .clk0   ( clk         ),
    .data0  ( 8'h0        ),
    .addr0  ( scan        ),
    .we0    ( 1'b0        ),
    .q0     ( ram_data    ),
    // CPU
    .clk1   ( clk         ),
    .data1  ( cpu_data    ),
    .addr1  ( cpu_AB      ),
    .we1    ( cpu_we      ),
    .q1     (             ) 
);

always @(posedge clk) begin
    case(bufcnt)
        4'b00_1: objbuf_data0 <= ram_data;
        4'b01_1: objbuf_data1 <= ram_data;
        4'b10_1: objbuf_data2 <= ram_data;
        4'b11_1: objbuf_data3 <= ram_data;
        default:;
    endcase
end


endmodule // jtgng_objdraw