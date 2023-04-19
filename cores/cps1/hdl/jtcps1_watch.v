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
    Date: 23-2-2021 */

module jtcps1_watch(
    input      rst,
    input      clk,
    input      pxl_cen,
    input      HB,
    input      VB,

    input      watch_scr1,
    input      watch_scr2,
    input      watch_scr3,
    input      watch_pal,
    input      watch_row,
    input      watch_obj,
    input      watch_vram_cs,
    input      pal_dma_ok,

    input      raster,

    input      ppu1_cs,
    input      ppu2_cs,
    input      objcfg_cs,

    output reg watch
);

localparam W=14;

(*keep*) wire [W-1:0] sig_in;
(*keep*) wire [W-1:0] sig_out;

assign sig_in = {
    VB,
    HB,
    watch_scr1,     // 11
    watch_scr2,     // 10
    watch_scr3,     // 9
    watch_pal,      // 8
    watch_row,
    watch_obj,
    watch_vram_cs,  // 5
    pal_dma_ok,     // 4
    raster,         // 3
    ppu1_cs,
    ppu2_cs,
    objcfg_cs
};

localparam CNTW=2;

reg [CNTW-1:0] cnt;
(*keep*) reg pxl4_cen;

always @(posedge clk) begin
    if( pxl_cen ) begin
        cnt<=cnt+1'd1;
        if( &cnt ) pxl4_cen<=1;
    end else begin
        pxl4_cen <= 0;
    end
end


generate
    genvar i;
    for( i=0; i<W; i=i+1 ) begin : enlargers
        jtframe_enlarger #(1) u_(
            .rst        ( rst           ),
            .clk        ( clk           ),
            .cen        ( pxl4_cen      ),
            .pulse_in   ( sig_in[i]     ),
            .pulse_out  ( sig_out[i]    )
        );
    end
endgenerate

always @(posedge clk) begin
    watch <= |sig_out;
end

endmodule