/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 17-05-2020 */

module jtframe_blank #(parameter DLY=4,DW=12)(
    input               clk,
    input               pxl_cen,
    input               preLHBL,
    input               preLVBL,
    output reg          LHBL,
    output reg          LVBL,
    output              preLBL,
    input      [DW-1:0] rgb_in,
    output reg [DW-1:0] rgb_out
);

wire [1:0] predly;

assign preLBL = predly==2'b11;

generate
    if( DLY>1 )
        jtframe_sh #(.W(2),.L(DLY-1)) u_dly(
            .clk    ( clk          ),
            .clk_en ( pxl_cen      ),
            .din    ( {preLHBL, preLVBL} ),
            .drop   ( predly       )
        );
    else
        assign predly = {preLHBL, preLVBL};
endgenerate

generate
    if( DLY > 0 ) begin : latch
        always @(posedge clk) if(pxl_cen) begin
            rgb_out <= predly==2'b11 ? rgb_in : {DW{1'b0}};
            {LHBL, LVBL} <= predly;
        end
    end else begin : comb // DLY==0
        always @(*) begin
            rgb_out = predly==2'b11 ? rgb_in : {DW{1'b0}};
            {LHBL, LVBL} = predly;
        end
    end
endgenerate

endmodule