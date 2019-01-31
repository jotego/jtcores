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
    input              wr_n,
    // memory output
    output  reg [7:0]  objbuf_data0,
    output  reg [7:0]  objbuf_data1,
    output  reg [7:0]  objbuf_data2,
    output  reg [7:0]  objbuf_data3
);

reg [6:0] scan, addr;
reg we;

always @(*) begin
    scan = { objcnt, pxlcnt[1:0] };
    if( SEATM_b ) begin
        addr = AB;
        we   = !wr_n;
    end else begin
        addr = scan;
        we   = 1'b0;
    end
end

wire [7:0] ram_data;

jtgng_ram #(.aw(7)) u_ram(
    .clk    ( clk         ),
    .cen    ( cen3        ),
    .data   ( DB          ),
    .addr   ( addr        ),
    .we     ( we          ),
    .q      ( ram_data    )
);

// Latches data output. It can be done without this, but
// I find this less prone to bugs
reg [31:0] collect;

always @(posedge clk) if(cen6) begin
    collect[31:0] <= {collect[23:0], ram_data };
    if( !SEATM_b && pxlcnt==4'd6 ) begin
        { objbuf_data2, objbuf_data3, objbuf_data0, objbuf_data1 } <= collect;
    end
end


endmodule // jtgng_objdraw