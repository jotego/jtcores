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
    Date: 28-8-2023 */

module jttwin16_obj(
    input             rst,
    input             clk,
    input             pxl_cen,

    // Base Video
    input             lhbl,
    input             lvbl,
    input             hs,
    input             vs,

    input      [ 8:0] vdump,
    input      [ 8:0] hdump,

    output reg        dma_bsy
);

reg lvbl_l;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dma_bsy <= 0;
        lvbl_l  <= 0;
    end else begin
        lvbl_l  <= lvbl;
        if( !lvbl && lvbl_l ) dma_bsy <= 1;
        if( vdump==9'h1f7 && hdump==9'hc9 ) dma_bsy <= 0;
    end
end

endmodule