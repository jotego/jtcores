/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 6-12-2022 */

`ifdef JTFRAME_PXLCLK
module jtframe_pxlcen(
    input       clk,
    input       ph24,       // toggles at every clk24 rising edge
    output reg  pxl_cen=0,
    output reg  pxl2_cen=0
);

    localparam PXLCLK = `JTFRAME_PXLCLK,
               CLK    = `ifdef JTFRAME_SDRAM96 96 `else 48 `endif,
               M      = PXLCLK==16 ? 3 : (PXLCLK==8 ? 3 : 4) << (CLK==96 ? 1:0),
               P      = CLK/24,             // clk cycles per clk24 period
               LP     = P==4 ? 2 : 1,
               L      = (2*M)%P==0 ? 2*M : 4*M; // multiple of the pixel and clk24 periods

    initial begin
        if( PXLCLK==16 && CLK!=96 ) begin
            $fatal(1,"JTFRAME_PXLCLK=16 requires JTFRAME_SDRAM96");
        end else if( PXLCLK!=16 && PXLCLK!=8 && PXLCLK!=6 ) begin
            $display("JTFRAME_PXLCLK is set to %d. But that value isn't supported yet.",PXLCLK);
            $finish;
        end else begin
            $display("jtframe_pxlcen: using %0d as clock divider", M[3:0]);
        end
    end

    // The pixel clock keeps a fixed phase with respect to clk24. As the video
    // timer runs freely, the frame start, and so the game reset release that
    // follows it, always fall on the same clk24 phase. This is needed for the
    // game to repeat exactly from one run to the next
    reg  [4:0] mc=0;
    reg  [1:0] ph_s=0;
    wire       ph_edge = ph_s[1]^ph_s[0];
    wire [4:0] mc_nx   = mc==L[4:0]-5'd1 ? 5'd0 : mc+5'd1;

    always @(posedge clk) begin
        ph_s     <= { ph_s[0], ph24 };
        mc       <= ph_edge ? { mc_nx[4:LP], {LP{1'b0}} } : mc_nx;
        pxl2_cen <= (mc % M)     == M-1;
        pxl_cen  <= (mc % (2*M)) == 2*M-1;
    end

endmodule
`endif
