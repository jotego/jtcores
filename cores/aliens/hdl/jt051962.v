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
    Date: 15-4-2023 */

// Based on Furrtek's RE work on die shots
// and MAME documentation
// 8x8 tiles
// Games that may be using this chip
// _88games, ajax, aliens, blockhl, blswhstl, bottom9, crimfght, cuebrick,
// ddboy, devstors, esckids, fuusenpn, gbusters, glfgreat, gradius3, lgtnfght,
// mainevt, mariorou, mia, parodius, prmrsocr, punkshot, scontra, shuriboy,
// simpsons, spy, ssriders, sunsetbl, surpratk, thndrx2, thunderx, tmnt, tmnt2,
// tsukande, tsupenta, tsururin, vendetta, xmen, xmen6p, xmenabl

// This is a simple chip that takes in the pixel data for each layer
// and synchronizes it. Contrary to most video hardware, it doesn't use
// a shift register to get each pixel from a tile but a decoder
// On FPGA, both implementations take similar area on the chip but I
// still prefer the shift register one as it seems simpler to understand
// The problem with the shift register approach is that it requires reading
// data close to the blanking edge, so it can be shifted to make any pixel
// the first one visible. These Konami chips read scroll data during blanking
// so those extra 8 pixels needed to read data in advanced are not available

// Note that for the fix layer, as it has no scroll, the shift register
// approach is still valid

module jt051962(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             flip,     // captured via the CPU bus in the original
    input             hflip_en,

    input      [ 1:0] cpu_addr,
    output     [ 7:0] cpu_din,

    input      [31:0] lyrf_data,
    input      [31:0] lyra_data,
    input      [31:0] lyrb_data,

    input      [ 7:0] lyrf_col,
    input      [ 7:0] lyra_col,
    input      [ 7:0] lyrb_col,

    input      [ 2:0] lyra_hsub,   // original pins: { ZA4H, ZA2H, ZA1H }
    input      [ 2:0] lyrb_hsub,   // original pins: { ZB4H, ZB2H, ZB1H }

    ouput      [ 8:0] hdump,    // not an output in the original
    ouput      [ 8:0] vdump,
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,

    output reg        lyrf_blank,
    output reg        lyra_blank,
    output reg        lyrb_blank,
    output     [ 7:0] lyrf_pxl,
    output     [11:0] lyra_pxl,
    output     [11:0] lyrb_pxl
);

wire [3:0] pxl_a, pxl_b;

jtframe_vtimer #(
    .HCNT_START ( 9'h020    ),
    .HCNT_END   ( 9'h19F    ),
    .HB_START   ( 9'h19F    ),
    .HB_END     ( 9'h05F    ),  // 10.6 us
    .HS_START   ( 9'h039    ),
    .HS_END     ( 9'h059    ),  //  5.33 us

    .V_START    ( 9'h0F8    ),
    .VB_START   ( 9'h1F0    ),
    .VB_END     ( 9'h110    ),  //  2.56 ms
    .VS_START   ( 9'h1FF    ),
    .VS_END     ( 9'h0FF    ),
    .VCNT_END   ( 9'h1FF    )   // 16.896 ms (59.18Hz)
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    (           ),
    .vrender1   (           ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( lhbl      ),
    .LVBL       ( lvbl      ),
    .HS         ( hs        ),
    .VS         ( vs        )
);

function [3:0] pxl_decod( input [2:0] sel, input [2:0] data);
    case(sel)
        0: pxl_decod = { data[24], data[16], data[ 8], data[0] };
        1: pxl_decod = { data[25], data[17], data[ 9], data[1] };
        2: pxl_decod = { data[26], data[18], data[10], data[2] };
        3: pxl_decod = { data[27], data[19], data[11], data[3] };
        4: pxl_decod = { data[28], data[20], data[12], data[4] };
        5: pxl_decod = { data[29], data[21], data[13], data[5] };
        6: pxl_decod = { data[30], data[22], data[14], data[6] };
        7: pxl_decod = { data[31], data[23], data[15], data[7] };
    endcase
endfunction

assign pxl_a = pxl_decod( lyra_hsel, lyra_data );
assign pxl_b = pxl_decod( lyrb_hsel, lyrb_data );
assign pxl_f = pxl_decod( lyrf_hsel, lyrf_data );

always @(posedge clk) begin
    if( pxl_cen ) begin
        if( hdump[2:0]==0 ) begin
            nx_cola     <= lyra_col;
            nx_colb     <= lyrb_col;
            nx_colf     <= lyrf_col;
            lyra_blank  <= pxl_a==0;
            lyrb_blank  <= pxl_b==0;
            lyrf_blank  <= pxl_fix==0;
            lyra_pxl[3:0] <=
        end
    end
end

endmodule