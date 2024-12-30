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
    Date: 28-10-2024 */

module jtwc_shared(
    input            rst,
    input            clk,
    // input            cen,
    // main
    input     [10:0] ma,
    input     [ 7:0] mdout,
    input            mwr_n,
    input            mxc8,
    input            mxd0,
    input            mxd8,
    input            mxe0,
    input            mxe8,
    output reg       msw,
    // sub
    input     [10:0] sa,
    input     [ 7:0] sdout,
    input            swr_n,
    input            sxc8,
    input            sxd0,
    input            sxd8,
    input            sxe0,
    input            sxe8,
    output reg       ssw,
    // shared RAM output
    input     [ 7:0] shram_dout,
    input     [15:0] pal16_dout,
    input     [15:0] fix16_dout,
    input     [15:0] vram16_dout,
    input     [ 7:0] obj_dout,
    // mux'ed
    output    [ 1:0] pal_we,
    output    [ 1:0] fix_we,
    output           obj_we,
    output    [ 1:0] scr_we,
    output           shram_we,
    output reg[10:0] sha,
    output reg[ 7:0] sha_din,
    output    [ 7:0] sha_dout,
    // video scroll
    output reg [8:0] scrx,
    output reg [7:0] scry
);

// mux'ed
wire        ram_cs, pal_cs, fix_cs, scr_cs, obj_cs, mnsel_n, sbsel_n;
reg         shc8, shd8, she0, she8, shd0, msel, ssel, sha_we;

function [7:0] mux8(input [15:0] a, input [3:0] sel );
begin
    mux8 = sha[sel] ? a[15:8] : a[7:0];
end
endfunction

// following mostly the names in the schematics
assign mnsel_n  = ~|{mxc8, mxd0, mxd8, mxe0, mxe8};
assign sbsel_n  = ~|{sxc8, sxd0, sxd8, sxe0, sxe8};
assign ram_cs   = shc8;
assign fix_cs   = shd0;
assign pal_cs   = shd8;
assign scr_cs   = she0;
assign obj_cs   = she8 && !sha[10];
assign shram_we =    ram_cs&sha_we;
assign obj_we   =    obj_cs&sha_we;
assign pal_we   = {2{pal_cs&sha_we}}&{sha[ 0],~sha[ 0]};
assign fix_we   = {2{fix_cs&sha_we}}&{sha[10],~sha[10]};
assign scr_we   = {2{scr_cs&sha_we}}&{sha[ 0],~sha[ 0]};
assign sha_dout = pal_cs ? mux8(pal16_dout, 0) :
                  fix_cs ? mux8(fix16_dout,10) :
                  scr_cs ? mux8(vram16_dout,0) :
                  obj_cs ? obj_dout : shram_dout;

always @* begin
    if( msel ) begin
        shc8    = mxc8;
        shd0    = mxd0;
        shd8    = mxd8;
        she0    = mxe0;
        she8    = mxe8;
        sha     = ma;
        sha_din = mdout;
        sha_we  = ~mwr_n;
    end else begin
        shc8    = sxc8;
        shd0    = sxd0;
        shd8    = sxd8;
        she0    = sxe0;
        she8    = sxe8;
        sha     = sa;
        sha_din = sdout;
        sha_we  = ~swr_n;
    end
end

always @(posedge clk) begin
    if(rst) begin
        {scrx,scry}  <= 0;
    end else if( she8 && sha[10] && sha_we ) begin
        case(sha[1:0])
            0: scrx[7:0] <= sha_din;
            1: scrx[8]   <= sha_din[0];
            2: scry      <= sha_din;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    if(rst) begin
        {msel,ssel}  <= 0;
        {msw, ssw }  <= 0;
    end else begin
        if( !mnsel_n &&  ssel    ) msw <= 1;
        if( !sbsel_n &&  msel    ) ssw <= 1;
        if(  mnsel_n && !sbsel_n ) {msel,ssel} <= 2'b01;
        if( !mnsel_n &&  sbsel_n ) {msel,ssel} <= 2'b10; // main has priority
        if(  mnsel_n &&  sbsel_n ) {msel,ssel} <= 2'b00;
        if( mnsel_n ) ssw <= 0;
        if( sbsel_n ) msw <= 0;
        if( !mnsel_n && !sbsel_n && {msel,ssel}==0 ) begin
            {msel,ssel} <= 2'b10;
            ssw <= 1;
        end
    end
end

endmodule