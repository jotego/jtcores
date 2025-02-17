/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 23-8-2020 */

module jtframe_tilebuf #(
    parameter          HW      = 8,
                       VW      = 8,
                       PALW    = 4,
                       HOFFSET = 0,
                       PW      = PALW+4,
    parameter [HW-1:0] HOVER = {HW{1'd1}} // H count at which a new line starts
) (
    input               rst,
    input               clk,
    input               pxl2_cen,

    // screen
    input      [HW-1:0] hdump,
    input      [VW-1:0] vdump,

    // to graphics block
    output              scan_cen,
    output reg [HW-1:0] hscan,
    output reg [VW-1:0] vscan,
    input      [PW-1:0] pxl_data,
    input               rom_ok,     // SDRAM output

    output     [PW-1:0] pxl_dump
);

reg           line, done;
wire [HW-1:0] hnext;
wire          we;
wire [HW-1:0] hread = hdump + HOFFSET[HW-1:0];

assign hnext = hscan + 1'd1;
assign we    = pxl2_cen & rom_ok & !done;
assign scan_cen = pxl2_cen & rom_ok;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hscan <= {HW{1'b0}};
        vscan <= {VW{1'b0}};
        line  <= 0;
        done  <= 0;
    end else begin
        vscan <= vdump+1'd1;

        if( hdump==HOVER ) begin
            if(done) line <= ~line;
            hscan <= HOVER;
            done  <= 0;
        end else
        if( we ) begin
            hscan <= hnext;
            if( hnext == HOVER ) done <= 1;
        end
    end
end

jtframe_dual_ram #(.AW(HW+1),.DW(PW)) u_line(
    .clk0   ( clk           ),
    .clk1   ( clk           ),
    // Port 0
    .data0  ( pxl_data      ),
    .addr0  ( {line,hscan}  ),
    .we0    ( we            ),
    .q0     (               ),
    // Port 1
    .data1  ( pxl_data      ),
    .addr1  ({~line,hread}  ),
    .we1    ( 1'b0          ),
    .q1     ( pxl_dump      )
);

endmodule
