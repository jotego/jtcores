/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 6-12-2022 */

`ifdef JTFRAME_PXLCLK
module jtframe_pxlcen(
    input       clk,
    input       ph24,
`ifdef JTFRAME_PXL_DIV
    output      pxl_cen,
    output      pxl2_cen
`else
    output reg  pxl_cen=0,
    output reg  pxl2_cen=0
`endif
);

    localparam PXLCLK = `JTFRAME_PXLCLK,
               CLK    = `ifdef JTFRAME_SDRAM96 96 `else 48 `endif,
               DIV    = `ifdef JTFRAME_PXL_DIV `JTFRAME_PXL_DIV
                        `else CLK/PXLCLK `endif;

    initial begin
        if( PXLCLK==16 && CLK!=96 ) begin
            $fatal(1,"JTFRAME_PXLCLK=16 requires JTFRAME_SDRAM96");
        end else if( PXLCLK!=16 && PXLCLK!=8 && PXLCLK!=6 ) begin
            $display("JTFRAME_PXLCLK is set to %d. But that value isn't supported yet.",PXLCLK);
            $finish;
        end else begin
            $display("jtframe_pxlcen: using %0d as clock divider", DIV);
        end
    end

`ifdef JTFRAME_PXL_DIV
    localparam N = DIV[0] ? 2 : 1,
               M = DIV[0] ? DIV : DIV/2;

    jtframe_frac_cen #(
        .WC ( 4 ),
        .W  ( 2 )
    ) u_cen(
        .clk  ( clk                   ),
        .n    ( N[3:0]                ),
        .m    ( M[3:0]                ),
        .cen  ( { pxl_cen, pxl2_cen } ),
        .cenb (                       )
    );
`else
    localparam [4:0] M = DIV[4:0] >> 1;
    localparam P  = CLK/24,
               LP = P==4 ? 2 : 1,
               L  = DIV%P==0 ? DIV : 2*DIV;

    reg  [4:0] mc=0;
    reg  [1:0] ph_s=0;
    wire       ph_edge = ph_s[1]^ph_s[0];
    wire [4:0] mc_nx   = mc==L[4:0]-5'd1 ? 5'd0 : mc+5'd1;

    always @(posedge clk) begin
        ph_s     <= { ph_s[0], ph24 };
        mc       <= ph_edge ? { mc_nx[4:LP], {LP{1'b0}} } : mc_nx;
        pxl2_cen <= (mc % M)        == M-5'd1;
        pxl_cen  <= (mc % DIV[4:0]) == DIV[4:0]-5'd1;
    end
`endif

endmodule
`endif
