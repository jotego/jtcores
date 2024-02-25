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
    Date: 9-8-2021 */

module jtexed_scr2 #(parameter
    HOFFSET  = 16'd0
) (
    input             rst,
    input             clk,
    input             pxl_cen,
    input      [ 8:0] V,
    input      [ 8:0] H,
    output reg [ 9:0] HF,
    input             flip,
    input       [2:0] pal_bank,
    input      [15:0] hpos,

    // PROM access
    input      [ 7:0] prog_addr,
    input      [ 3:0] prog_din,
    input      [ 1:0] prom_we,

    // Map ROM
    output reg [11:0] map2_addr,
    input      [15:0] map2_data,
    output reg        map2_cs,
    input             map2_ok,

    output reg [13:2] rom2_addr,
    input      [31:0] rom2_data,
    input             rom2_ok,
    // Output pixel
    input             scr2_on,    // low makes the output FF
    output      [5:0] scr2_pxl,
    input       [7:0] debug_bus
);

reg  [15:0] heff, hadv;
reg  [ 9:0] Hfix;
wire [15:0] hpos_adj = hpos + HOFFSET;

wire hflip = map2_data[6]^flip;
wire vflip = ~(map2_data[7]^~flip);

always @(*) begin
    if( H>9'hc0 && H<9'h100 )
        Hfix = { 2'h3 ^ {flip,1'b0}, H[7:0] };
    else if( H[8] )
        Hfix = { 2'h0, H[7:0] };
    else
        Hfix = { 2'h1 ^ {flip,1'b0}, H[7:0] };
    Hfix[7:0] = Hfix[7:0] ^ {8{flip}};

    heff = hpos_adj + { {6{Hfix[9]}}, Hfix };
    if( flip ) heff = heff - 16'd11;
    hadv = flip ? heff - 16'h10 : heff + 16'h10;
end

always @(posedge clk) begin
    HF <= Hfix;
end

reg         hflip2;
reg  [15:0] pxl_msb, pxl_lsb;
reg  [ 2:0] pal_hsb;
wire [ 7:0] pal_addr;
wire [ 1:0] cur_pxl = hflip2 ? { pxl_msb[0], pxl_lsb[0] } : { pxl_msb[15], pxl_lsb[15] };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom2_addr <= 0;
        pxl_lsb   <= 0;
        pxl_msb   <= 0;
        pal_hsb   <= 0;
    end else if(pxl_cen) begin
        if( heff[3:0]==0 ) begin
            pxl_msb <= { rom2_data[3:0], rom2_data[11: 8], rom2_data[19:16], rom2_data[27:24] };
            pxl_lsb <= { rom2_data[7:4], rom2_data[15:12], rom2_data[23:20], rom2_data[31:28] };
            hflip2   <= hflip;
            pal_hsb  <= map2_data[10:8];
            map2_addr <= { hadv[13:8], V[7:5]^{3{flip}}, hadv[7:5] }; // 6+3+3 = 12
            map2_cs   <= 1;
        end else begin
            if(map2_ok) begin
                map2_cs <= 0;
                rom2_addr <= { map2_data[5:0], V[4:0]^{5{vflip}}, heff[4]^~hflip }; // 6+5+1+1 = 13
            end
            if( hflip2 ) begin
                pxl_lsb <= pxl_lsb >> 1;
                pxl_msb <= pxl_msb >> 1;
            end else begin
                pxl_lsb <= pxl_lsb << 1;
                pxl_msb <= pxl_msb << 1;
            end
        end
    end
end

assign pal_addr = { pal_bank, pal_hsb, cur_pxl };

wire [7:0] prom_data;

jtframe_prom #(.AW(8),.DW(4)) u_prom_l4(
    .clk    ( clk        ),
    .cen    ( 1'b1       ),
    .data   ( prog_din   ),
    .rd_addr( pal_addr   ),
    .wr_addr( prog_addr  ),
    .we     ( prom_we[0] ),
    .q      ( prom_data[3:0]  )
);

jtframe_prom #(.AW(8),.DW(4)) u_prom_l3(
    .clk    ( clk        ),
    .cen    ( 1'b1       ),
    .data   ( prog_din   ),
    .rd_addr( pal_addr   ),
    .wr_addr( prog_addr  ),
    .we     ( prom_we[1] ),
    .q      ( prom_data[7:4]  )
);


assign scr2_pxl = scr2_on ? prom_data[5:0] : 6'h3f;


endmodule