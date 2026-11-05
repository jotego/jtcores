/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 6-12-2022 */

`ifdef JTFRAME_PXLCLK
module jtframe_pxlcen(
    input   clk,
    output  pxl_cen,
    output  pxl2_cen
);

    localparam PXLCLK = `JTFRAME_PXLCLK,
               CLK    = `ifdef JTFRAME_SDRAM96 96 `else 48 `endif,
               DIV    = `ifdef JTFRAME_PXL_DIV `JTFRAME_PXL_DIV
                        `else CLK/PXLCLK `endif,
               N      = DIV[0] ? 2 : 1,
               M      = DIV[0] ? DIV : DIV/2;

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

    jtframe_frac_cen #(.WC(4),.W(2)) u_cen(
        .clk    ( clk       ),    // 48 or 96 MHz
        .n      ( N[3:0]    ),
        .m      ( M[3:0]    ),
        .cen    ( { pxl_cen, pxl2_cen } ),
        .cenb   (           )
    );

endmodule
`endif
