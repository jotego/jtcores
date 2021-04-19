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
    Date: 19-4-2021 */

module jt1943_map_cache #(parameter
    // MAP SIZE
    MAPAW = 14, // address width
    MAPDW = 16, // data width
    [8:0] HEND  = 9'h0FF
) (
    input                rst,
    input                clk,  // >12 MHz
    input                pxl_cen,
    output               mapper_cen,

    input                LHBL,
    input         [ 8:0] H, // H256-H1

    output        [ 8:0] map_h, // H256-H1
    output reg           draw_en,

    // Map ROM to SDRAM
    input    [MAPDW-1:0] map_data,
    input                map_ok,
    output reg           map_cs,

    // Map ROM from mapper
    output   [MAPDW-1:0] mapper_data
);

localparam CACHEW = 5; //up to 32 tiles => 512 for 16x16 tiles

reg  [1:0] st;
reg        last_LHBL, okidle;
reg  [8:0] hcnt;
wire       map_we;

assign map_we     = map_ok && map_cs;
assign mapper_cen = draw_en ? pxl_cen : 1'b1;
assign map_h      = draw_en ? H : hcnt;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        draw_en   <= 1;
        last_LHBL <= 1;
        okidle    <= 0;
        st        <= 0;
    end else begin
        last_LHBL <= LHBL;
        if( !LHBL && last_LHBL ) begin
            draw_en  <= 0;
            hcnt    <= 9'h100;
            st       <= 0;
        end
        // cache filler
        if( !draw_en ) begin
            st <= st+2'd1;
            case( st )
                0: map_cs <= 1;
                2: begin
                    if( !map_ok )
                        st <= 2;
                    else begin
                        map_cs <= 0;
                        if( hcnt == HEND )
                            draw_en <= 1;
                        else
                            hcnt  <= hcnt + 1'd1;
                    end
                end
            endcase
        end else begin
            map_cs <= 1;
        end
    end
end

// hcnt[8], H[8] are always 1 for 256-wide screens
// CACHEW could be optimized
jtframe_dual_ram #(.dw(MAPDW),.aw(CACHEW)) u_cache(
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    // Port 0: writes
    .data0  ( map_data  ),
    .addr0  ( hcnt[8:4] ),
    .we0    ( map_we    ),
    .q0     (           ),
    // Port 1: reads
    .data1  (           ),
    .addr1  ( H[8:4]    ),
    .we1    ( 1'b0      ),
    .q1     ( mapper_data )
);

endmodule