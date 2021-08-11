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
    Date: 11-8-2021 */

module jtexed_scr1 #(parameter
    [11:0] HOFFSET  = 0
) (
    input             rst,
    input             clk,
    input             pxl_cen,
    input      [ 8:0] V,
    input      [ 8:0] H,
    input             flip,
    input       [2:0] pal_bank,
    input      [10:0] hpos,
    input      [10:0] vpos,

    // PROM access
    input      [ 7:0] prog_addr,
    input      [ 3:0] prog_din,
    input      [ 1:0] prom_we,

    // Map ROM
    output reg [13:0] map1_addr,
    input      [ 7:0] map1_data,
    output reg        map1_cs,
    input             map1_ok,

    output reg [13:0] rom1_addr,
    input      [31:0] rom1_data,
    input             rom1_ok,
    // Output pixel
    input             scr1_on,    // low makes the output FF
    output      [3:0] scr1_pxl,
    input       [7:0] debug_bus
);

reg         hmsb, yh7;
reg  [11:0] heff, hadv, veff;
//reg  [ 8:0] hfix;

always @(*) begin
    hmsb = ~H[8] & H[6];
    yh7  = H[6] ^ ( ~H[8] & ~H[6] );
    //heff = hpos + { {7{hmsb}}, ~H[8], yh7, H[6:0] } + HOFFSET;
//    if( H>=9'h100 )
//        hfix = H ^ 9'h100;
//    else if( H< 9'hC0 )
//        hfix = { 2'b10, H[6:0] };
//    else
//        hfix = { 2'b}

    heff = hpos + HOFFSET + { 4'd0, ~H[8], H[8] ? H[7] : ~H[7], H[6:0] }; // + {8'd0, debug_bus};
    hadv = heff;// + 16'd16;

    veff = { 1'b0, vpos[10:0] } + { 4'd0, V[7:0] };
end

reg  [7:0] pxl_w, pxl_x, pxl_y, pxl_z;
wire [7:0] pal_addr;
wire [3:0] cur_pxl =!flip ? { pxl_w[0], pxl_x[0], pxl_y[0], pxl_z[0] } :
                            { pxl_w[7], pxl_x[7], pxl_y[7], pxl_z[7] };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom1_addr <= 0;
        pxl_w     <= 0;
        pxl_x     <= 0;
        pxl_y     <= 0;
        pxl_z     <= 0;
    end else if(pxl_cen) begin
        if( heff[2:0]==0 ) begin
            pxl_z <= { rom1_data[ 3: 0], rom1_data[19:16] };
            pxl_y <= { rom1_data[ 7: 4], rom1_data[23:20] };
            pxl_x <= { rom1_data[11: 8], rom1_data[27:24] };
            pxl_w <= { rom1_data[15:12], rom1_data[31:28] };
            map1_addr <= { veff[10:8], hadv[10:8], veff[7:4], hadv[7:4] }; // 3+3+4+4=14
            map1_cs   <= 1;
        end else begin
            if(map1_ok) begin
                map1_cs <= 0;
                rom1_addr <= { map1_data, veff[3:0], heff[3] }; // 8+4+1=13
            end
            if( !flip ) begin
                pxl_w <= pxl_w >> 1;
                pxl_x <= pxl_x >> 1;
                pxl_y <= pxl_y >> 1;
                pxl_z <= pxl_z >> 1;
            end else begin
                pxl_w <= pxl_w << 1;
                pxl_x <= pxl_x << 1;
                pxl_y <= pxl_y << 1;
                pxl_z <= pxl_z << 1;
            end
        end
    end
end

assign pal_addr = { pal_bank, 1'b0, cur_pxl };

wire [3:0] prom_data;

jtframe_prom #(.aw(8),.dw(4)) u_prom_c4(
    .clk    ( clk        ),
    .cen    ( 1'b1       ),
    .data   ( prog_din   ),
    .rd_addr( pal_addr   ),
    .wr_addr( prog_addr  ),
    .we     ( prom_we[0] ),
    .q      ( prom_data  )
);


assign scr1_pxl = scr1_on ? prom_data : 4'hf;

endmodule