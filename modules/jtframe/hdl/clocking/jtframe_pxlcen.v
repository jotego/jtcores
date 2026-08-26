/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
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
               M      = (PXLCLK==12 ? 2 : PXLCLK==8 ? 3 : 4) << (CLK==96 ? 1:0);

    initial begin
        if( PXLCLK!=8 && PXLCLK!=6 ) begin
            $display("JTFRAME_PXLCLK is set to %d. But that value isn't supported yet.",PXLCLK);
            $finish;
        end else begin
            $display("jtframe_pxlcen: using %0d as clock divider", M[3:0]);
        end
    end

    jtframe_frac_cen #(.WC(4),.W(2)) u_cen(
        .clk    ( clk       ),    // 48 or 96 MHz
        .n      ( 4'd1      ),
        .m      (M[3:0]),
        .cen    ( { pxl_cen, pxl2_cen } ),
        .cenb   (           )
    );

endmodule
`endif
