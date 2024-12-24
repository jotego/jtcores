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
    Date: 30-3-2024 */

module jtshouse_obj_dma(
    input             rst,
    input             clk,

    input             pxl_cen,    
    input             lvbl,
    input             hs,
    input             dma_on,
    output reg        dma_bsy,
    // Video RAM
    output reg [ 6:0] dma_obj,
    output reg [ 2:0] oram_sub,
    input      [15:0] oram_dout,
    output reg        oram_we,
    output reg [15:0] oram_din
);

// DMA
reg         nx_dma, lvbl_l;
reg  [ 2:0] dma_sub;
reg  [ 1:0] dma_st;
wire        vb_edge;

assign vb_edge = ~lvbl & lvbl_l;

// DMA - sequence length NOT measured on PCB yet
always @* begin
    case( {oram_we, dma_sub} )
        4'b0_001: oram_sub = 3'b010; // 4-5
        4'b0_010: oram_sub = 3'b011; // 6-7
        4'b0_100: oram_sub = 3'b100; // 8-9

        4'b1_001: oram_sub = 3'b101; // 10-11
        4'b1_010: oram_sub = 3'b110; // 12-13
        4'b1_100: oram_sub = 3'b111; // 14-15
        default:  oram_sub = 3'b111;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        nx_dma   <= 0;
        dma_bsy  <= 0;
        dma_st   <= 0;
        dma_obj  <= 0;
        dma_sub  <= 0;
        lvbl_l   <= 0;
    end else begin
        dma_st <= dma_st+2'd1;
        lvbl_l <= lvbl;

        if( dma_on `ifdef SIMSCENE || (hs&&lvbl) `endif ) nx_dma <= 1;
        if( nx_dma && vb_edge ) begin
            nx_dma   <= 0;
            dma_bsy  <= 1;
            dma_st   <= 0;
            dma_obj  <= 0;
            dma_sub  <= 1;
        end
        if( dma_bsy ) case(dma_st)
            2: begin
                oram_din <= oram_dout;
                oram_we  <= 1;
            end
            3: begin
                oram_we <= 0;
                if( dma_sub[2] ) begin
                    dma_obj <= dma_obj+7'd1;
                    if( &dma_obj[6:1] ) dma_bsy <= 0;
                end
                dma_sub <= { dma_sub[1:0], dma_sub[2] };
            end
            default:;
        endcase
    end
end

endmodule