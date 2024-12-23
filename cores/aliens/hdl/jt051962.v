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

// But the original chip gets the tile data at the pixel rate, whereas that rate
// is hard to get with the SDRAM. It is easier to give 8-pixel margin to the
// SDRAM to get the data from the three layers. That means 64 48MHz-clock ticks
// to make 3 requests of about 9 ticks each, adding up to 27 ticks, or half the
// available time. It's quite demanding but arrenging the tile data during
// SDRAM download so the V bits go up and enabling 64-bit reads, will make the
// cache work for most of layer A/B and some parts of the fix layer
// That will reduce the SDRAM ticks used for tiles to about 30 out of 128
// or ~25% instead of the ~50% without cache

// If data reads require an 8-pixel margin, using a decoder would require an
// 8-clock delay for the sub-tile indexes, or 3x2x8=48 flip flops. The color
// bytes may also require per-pixel delay instead of per-tile.

// So, I'd rather change what the tile mapper does during blanking so data can
// be grabbed at the edge of blanking and a regular bit shifting approach
// can be used to save flip flop count

module jt051962(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             flip,     // captured via the CPU bus in the original
    input             hflip_en,

    input      [ 1:0] cpu_addr,
    output reg [ 7:0] cpu_din,

    input      [31:0] lyrf_data,
    input      [31:0] lyra_data,
    input      [31:0] lyrb_data,

    input      [ 7:0] lyrf_col,
    input      [ 7:0] lyra_col,
    input      [ 7:0] lyrb_col,

    // Fine grain scroll
    input      [ 2:0] hsub_a, hsub_b,


    output     [ 8:0] hdump,    // not an output in the original
    output     [ 8:0] vdump, vrender, vrender1,
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,

    output            lyrf_blnk_n,
    output            lyra_blnk_n,
    output            lyrb_blnk_n,
    output     [ 7:0] lyrf_pxl,
    output     [11:0] lyra_pxl,
    output     [11:0] lyrb_pxl,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus
);

parameter [8:0] HB_OFFSET=0,
                HB_EXTRAL=0,
                HB_EXTRAR=0;

reg  [7:0] cola, colb, colf;
reg [31:0] pxlf_data, pxla_data, pxlb_data;
reg        hflipa, hflipb;

jtframe_vtimer #(
    .HCNT_START ( 9'h020    ),
    .HCNT_END   ( 9'h19F    ),
    .HB_START   ( 9'h029+HB_OFFSET-HB_EXTRAR ),
    .HB_END     ( 9'h069+HB_OFFSET+HB_EXTRAL ),  // 10.67 us in RE verilog model
    .HS_START   ( 9'h034    ),

    .V_START    ( 9'h0F8    ),
    .VB_START   ( 9'h1EF    ),
    .VB_END     ( 9'h10F    ),  //  2.56 ms
    .VS_START   ( 9'h1FF    ),  // ~512.5us, measured on X-Men PCB
    .VS_END     ( 9'h0FF    ),
    .VCNT_END   ( 9'h1FF    )   // 16.896 ms (59.18Hz)
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( lhbl      ),
    .LVBL       ( lvbl      ),
    .HS         ( hs        ),
    .VS         ( vs        )
);

function [3:0] colidx( input hf, input [31:0] data );
    colidx = hf ? {data[24],data[16],data[ 8],data[0]} :
                  {data[31],data[23],data[15],data[7]};
endfunction

function [31:0] shift( input hf, input [31:0] data);
    shift = hf ? data >> 1 : data << 1;
endfunction

// Tile ROM reads by the CPU
// This will need to include a wait state
always @(posedge clk) begin
    case( cpu_addr^debug_bus[1:0] )
        2'd0: cpu_din <= lyra_data[ 7: 0];
        2'd1: cpu_din <= lyra_data[15: 8];
        2'd2: cpu_din <= lyra_data[23:16];
        2'd3: cpu_din <= lyra_data[31:24];
    endcase
end

assign lyrf_pxl = { colf[7:4],colidx(  flip, pxlf_data) };
assign lyra_pxl = { cola[3:0], cola[7:4], colidx(hflipa, pxla_data) };
assign lyrb_pxl = { colb[3:0], colb[7:4], colidx(hflipb, pxlb_data) };

assign lyrf_blnk_n = lyrf_pxl[3:0]!=0 & gfx_en[0];
assign lyra_blnk_n = lyra_pxl[3:0]!=0 & gfx_en[1];
assign lyrb_blnk_n = lyrb_pxl[3:0]!=0 & gfx_en[2];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pxla_data <= 0;
        pxlb_data <= 0;
        pxlf_data <= 0;
        cola      <= 0;
        colb      <= 0;
        colf      <= 0;
        hflipa    <= 0;
        hflipb    <= 0;
    end else if( pxl_cen ) begin
        if( hsub_a[2:0]==0 ) begin
            pxla_data <= lyra_data;
            cola      <= lyra_col;
            hflipa    <= (hflip_en & lyra_col[0]) ^ flip;
        end else begin
            pxla_data <= shift( hflipa, pxla_data );
        end

        if( hsub_b[2:0]==0 ) begin
            pxlb_data <= lyrb_data;
            colb      <= lyrb_col;
            hflipb    <= (hflip_en & lyrb_col[0]) ^ flip;
        end else begin
            pxlb_data <= shift( hflipb, pxlb_data );
        end

        if( hdump[2:0]==0 ) begin
            pxlf_data <= lyrf_data;
            colf      <= lyrf_col;
        end else begin
            pxlf_data <= shift(  flip , pxlf_data );
        end
    end
end

endmodule