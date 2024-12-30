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
    Date: 27-8-2023 */

module jttwin16_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,

    // Base Video
    input             lhbl,
    input             lvbl,

    // BRAM interface
    output     [11:0] pal_addr,
    input      [ 7:0] pal_dout,

    // CPU interface
    input      [ 2:0] prio,

    // Final pixels
    input      [ 7:0] lyrf_pxl,
    input      [ 6:0] lyra_pxl,
    input      [ 6:0] lyrb_pxl,
    input      [ 7:0] lyro_pxl,
    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus
);

reg  [ 1:0] lyr_sel;
reg         pal_half, shl;
reg  [ 9:0] pxl;
reg  [15:0] pxl_aux;
reg  [23:0] bgr;
reg         shad;
wire        lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n;
wire        shadow_pen, trans_pen;

assign      lyrf_blnk_n = gfx_en[0] & |lyrf_pxl[3:0];
assign      lyra_blnk_n = gfx_en[1] & |lyra_pxl[3:0];
assign      lyrb_blnk_n = gfx_en[2] & |lyrb_pxl[3:0];
assign      shadow_pen  = gfx_en[3] && &lyro_pxl[3:0];
assign      trans_pen   =!gfx_en[3] || lyro_pxl[3:0]==0;


assign pal_addr  = { 1'b0, pxl, pal_half };
assign {blue,green,red} = (lvbl & lhbl ) ? bgr : 24'd0;

always @* begin
    case( lyr_sel )
        0: pxl = { 3'b101, lyrb_pxl };
        1: pxl = { 3'b100, lyra_pxl };
        2: pxl = { 2'b01,  lyro_pxl };
        3: pxl = { 2'b00,  lyrf_pxl };
    endcase
end

function [23:0] dim( input [14:0] cin, input shade );
    dim = !shade? { 1'b0, cin[14:10], cin[14:13],
                    1'b0, cin[ 9: 5], cin[ 9: 8],
                    1'b0, cin[ 4: 0], cin[ 4: 3] } :
                  { cin[14:10], cin[14:12],
                    cin[ 9: 5], cin[ 9: 7],
                    cin[ 4: 0], cin[ 4: 2] };
endfunction

always @(posedge clk) begin
    if( rst ) begin
        pal_half <= 0;
        bgr      <= 0;
        shl      <= 0;
    end else begin
`ifndef GRAY
        pxl_aux <= { pxl_aux[7:0], pal_dout };
`else
        pxl_aux <= {1'b0,{3{pxl[4:0]}}};
`endif
        if( pxl_cen ) begin
            shl <= shad;
            bgr <= dim(pxl_aux[14:0], shl);
            pal_half <= 0;
        end else
            pal_half <= ~pal_half;
    end
end

always @* begin
    shad = !((!lyrf_blnk_n && shadow_pen) && (
           (!prio[1]                 ) ||
           (!prio[0] && !lyra_blnk_n ) ||
           ( prio[0] && !lyrb_pxl[6] ) ||
           ( prio[0] && !lyrb_blnk_n )));
    lyr_sel[1] = lyrf_blnk_n || ( // SELB: f/o vs a/b
                !shadow_pen  &&
                !trans_pen   &&
                !(prio[1:0]==1 && lyra_blnk_n ) &&
                !(prio[1:0]==3 && lyrb_blnk_n && lyrb_pxl[6])
                );
    lyr_sel[0] = lyrf_blnk_n || // SELA: f vs o and a vs b
                (!prio[1] &&    prio[0] &&  lyra_blnk_n ) ||
                (!prio[1] && shadow_pen &&  lyra_blnk_n ) ||
                (!prio[1] &&  trans_pen &&  lyra_blnk_n ) ||
                ( prio[1] && shadow_pen && !lyrb_blnk_n ) ||
                ( prio[1] &&  trans_pen && !lyrb_blnk_n );

end

endmodule