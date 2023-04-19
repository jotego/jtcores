/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 29-9-2021 */


// Star field generator
// Based on research work by Loic
// https://gitlab.com/loic.petit/cps2-reverse

module jtcps1_stars(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              HS,
    input              VB,
    input              flip,
    input      [ 8:0]  hdump,
    input      [ 8:0]  vdump,
    // control registers
    input      [ 8:0]  hpos,
    input      [ 8:0]  vpos,

    output     [12:0]  rom_addr,
    input      [31:0]  rom_data,
    input              rom_ok,
    output             rom_cs,

    output reg [ 6:0]  pxl,
    input      [ 7:0]  debug_bus
);

parameter FIELD=0;

reg  [3:0] cnt16, cnt15, fcnt, cache_cnt;
reg  [2:0] pal_id;
reg  [4:0] pos, xs_cnt;
reg  [7:0] star_data;
reg  [8:0] veff;
reg        VBl, HSl, cache_fill, blank;
reg  [3:0] rom_hpos;

reg  [7:0] cache[0:15];

assign rom_cs   = cache_fill;
assign rom_addr = { veff[8], rom_hpos, veff[7:0] };

always @(posedge clk) if(pxl_cen) begin
    HSl <= HS;
    if( !HS && HSl ) begin // start the filling after HS (vdump toggles before)
        cache_fill <= 1;
        cache_cnt  <= 0;
    end
    if( cache_fill ) begin
        if( rom_ok ) begin // not need for wait state because of pxl_cen
            cache[ cache_cnt ] <= rom_data[7:0];
            if( cache_cnt==4'hf ) begin
                cache_fill <= 0;
            end else begin
                cache_cnt <= cache_cnt + 1'd1;
            end
        end
    end
end

always @(posedge clk) begin
    star_data <= cache[ hdump[8:5] ];
end

always @* begin
    rom_hpos = ((hpos[8:5] + cache_cnt + 4'd1 ) ^ {4{flip}}); // stars-x schematic
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cnt15 <= 0;
        cnt16 <= 0;
        veff  <= 0;
        fcnt  <= 0;
    end else if( pxl_cen ) begin
        veff <= (vpos+vdump)^{9{flip}};
        VBl  <= VB;
        if( VB & ~VBl ) begin
            fcnt <= fcnt+1'd1;
            if( &fcnt[3:0] ) begin
                cnt15 <= cnt15==14 ? 4'd0 : cnt15+1'd1; // cnt15 will never be transparent
                cnt16 <= cnt16+1'd1; // transparent when cnt16==15
            end
        end
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pxl <= 7'hf;
        xs_cnt <= 0;
    end else if( pxl_cen ) begin
        if( hdump[4:0]==0 ) begin
            xs_cnt <= ~hpos[4:0];
        end else begin
            xs_cnt <= xs_cnt-1'd1;
        end
        if( xs_cnt==0 ) begin
            pal_id <= star_data[7:5];
            pos    <= star_data[4:0]^{5{flip}};
            blank  <= star_data[4:0]==5'hf;
        end else begin
            pos <= pos-1'd1;
        end
        pxl[6:4] <= pal_id;
        pxl[3:0] <= pos==0 && !blank ? (pal_id[2] ? cnt16 : cnt15) : 4'hf;
    end
end

endmodule