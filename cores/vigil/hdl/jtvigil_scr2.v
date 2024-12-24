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
    Date: 30-4-2022 */

module jtvigil_scr2(
    input         rst,
    input         clk,
    input         pxl_cen,
    input         flip,

    input  [ 8:0] h,
    input  [ 8:0] v,
    input         LHBL,
    input         LVBL,
    input         HS,
    input  [10:0] scrpos,
    output [18:2] rom_addr,
    input  [31:0] rom_data, // 32/4 = 8 pixels
    output        rom_cs,
    input         rom_ok,
    output [ 3:0] pxl,
    input  [ 7:0] debug_bus
);

reg  [11:0] hsum;
wire [11:0] hnext;
reg  [31:0] pxl_data;
wire [ 3:0] buf_in;
reg  [ 8:0] hcnt, buf_addr, vbuf;
reg         done, LHBL_l;
wire        we;

assign rom_cs   = !done;
assign we       = !done;
assign rom_addr = { /*debug_bus[7:4]*/ 1'b0, hsum[10:9],
    vbuf[7:0], hsum[8:3] /*, ~flip*/ };
assign hnext    = { 2'b11, hcnt^{9{~flip}} } + scrpos + 12'h7E;

assign buf_in = hsum[0] /*^ flip*/ ?
    { pxl_data[6], pxl_data[4], pxl_data[2], pxl_data[0] } :
    { pxl_data[7], pxl_data[5], pxl_data[3], pxl_data[1] };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        LHBL_l <= 0;
        done   <= 0;
        hcnt   <= 0;
        hsum   <= 0;
    end else if(pxl_cen) begin
        LHBL_l <= LHBL;
        if( LHBL && !LHBL_l ) begin
            done <= 0;
            hcnt <= 9'h1ff;
            vbuf <= v;
            hsum <= hnext;
        end
        if( !done && rom_ok ) begin
            buf_addr <= hcnt;
            hcnt <= hcnt + 9'd1;
            hsum <= hnext;
            case( hsum[2:0] )   // 8 pixel delay
                0: pxl_data <= ~flip ?
                    { rom_data[15:0], rom_data[31:16] } :
                    rom_data;
                2,4,6: begin
                    pxl_data <= pxl_data >> 8;
                end
            endcase
            if( hcnt==9'h117 ) begin
                done <= 1;
                hcnt <= 0;
            end
        end
    end
end

jtframe_linebuf #(.DW(4)) u_buffer(
    .clk    ( clk       ),
    .LHBL   ( HS        ),
    // New data writes
    .wr_addr( buf_addr  ),
    .wr_data( buf_in    ),
    .we     ( we        ),
    // Old data reads (and erases)
    .rd_addr( h         ),
    .rd_data( pxl       ),
    .rd_gated(          )
);


endmodule