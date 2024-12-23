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
    Date: 26-1-2021 */

// See file cc/brightness.cc for the LUT generation

module jtcps1_pal(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             vb,
    input             hb,
    output            LVBL,
    output            LHBL,

    input      [11:0] pxl_in,
    output     [11:0] pal_addr,
    input      [15:0] pal_raw,

    output reg [ 7:0] red,
    output reg [ 7:0] green,
    output reg [ 7:0] blue
);

parameter BLNK_DLY=4;

wire [ 3:0] raw_r, raw_g, raw_b, raw_br;
reg  [ 7:0] lut_r, lut_g, lut_b;
reg  [ 3:0] lut_addr;
wire [ 7:0] lut_dout;
reg  [ 2:0] lut_k; // counter

assign pal_addr = pxl_in;

`ifdef GRAY
assign raw_br   = 4'hf ;
assign raw_r    = pal_addr[3:0];
assign raw_g    = pal_addr[3:0];
assign raw_b    = pal_addr[3:0];
`else
assign raw_br   = pal_raw[15:12]; // r
assign raw_r    = pal_raw[11: 8]; // br
assign raw_g    = pal_raw[ 7: 4]; // b
assign raw_b    = pal_raw[ 3: 0]; // g
`endif

jtframe_ram #(.AW(8),.SYNFILE("pal_lut.hex")) u_lut (
    .clk    ( clk                  ),
    .cen    ( 1'b1                 ),
    .data   ( 8'd0                 ),
    .addr   ( { raw_br, lut_addr } ),
    .we     ( 1'b0                 ),
    .q      ( lut_dout             )
);

always @(posedge clk, posedge rst) begin
    if(rst) begin
        lut_r    <= 8'h0;
        lut_g    <= 8'h0;
        lut_b    <= 8'h0;
        lut_k    <= 3'd0;
        lut_addr <= 4'd0;
    end else begin // the clock frequency must be a multiple of 3*8=24MHz
        if( pxl_cen ) begin
            lut_k <= 3'd0;
        end else if( lut_k != 3'd7 )
            lut_k <= lut_k+3'd1;
        case( lut_k )
            3'd2: begin
                lut_addr <= raw_r;
            end
            3'd3: begin
                lut_addr <= raw_g ;
            end
            3'd4: begin
                lut_r    <= lut_dout;
                lut_addr <= raw_b;
            end
            3'd5: begin
                lut_g    <= lut_dout;
            end
            3'd6: begin
                lut_b    <= lut_dout;
            end
            default:;
        endcase
    end
end

always @(posedge clk, posedge rst) begin
    if(rst) begin
        red   <= 8'd0;
        green <= 8'd0;
        blue  <= 8'd0;
    end else if(pxl_cen) begin
        // signal * 17 - signal*15/2 - signal*15/4 = signal * (17-15/2-15/4)
        // 66% max attenuation for brightness
        if( vb || (hb && !LHBL) ) begin
            red   <= 8'd0;
            green <= 8'd0;
            blue  <= 8'd0;
        end else begin
            red   <= lut_r;
            green <= lut_g;
            blue  <= lut_b;
        end
    end
end

jtframe_sh #(.W(2),.L(BLNK_DLY)) u_sh(
    .clk    ( clk          ),
    .clk_en ( pxl_cen      ),
    .din    ( {~vb, ~hb}   ),
    .drop   ( {LVBL, LHBL} )
);

endmodule