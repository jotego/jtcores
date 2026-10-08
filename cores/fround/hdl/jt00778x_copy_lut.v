/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-12-2024 */

module jt00778x_copy_lut(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             objbufinit,
    input             dma_on,
    output reg        dma_bsy=0,

    output     [13:1] oram_addr,
    input      [15:0] oram_dout,
    output     [15:0] oram_din,
    output            oram_we
);

reg         obi_l;
wire [11:1] nx_addr;
reg  [10:1] lo_addr;

assign oram_addr = { 3'b110, lo_addr};
assign nx_addr   = {1'b1,lo_addr}+1'd1;
assign oram_din  = oram_dout;
assign oram_we   = dma_bsy;

always @(posedge clk) begin
    if( rst ) begin
        dma_bsy  <= 0;
    end else if( pxl_cen ) begin
        obi_l <= objbufinit;
        if( objbufinit && !obi_l ) begin
            if(dma_on) begin
                dma_bsy <= 1;
            end
            lo_addr <= 0;
        end
        if( dma_bsy ) begin
            {dma_bsy,lo_addr} <= nx_addr;
        end
    end
end

endmodule