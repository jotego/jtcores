/*  JTCORES wrapper for IKAOPM.

    The wrapped IKAOPM sources are Copyright (c) 2022, Raki and distributed
    under the BSD 2-Clause License found in modules/ikaopm/LICENSE.
*/

module jtikaopm(
    input                     rst,
    input                     clk,
    input                     cen,
    input                     cs_n,
    input                     rd_n,
    input                     wr_n,
    input                     a0,
    input              [ 7:0] din,
    output             [ 7:0] dout,
    output                    ct1,
    output                    ct2,
    output                    irq_n,
    output signed      [15:0] left,
    output signed      [15:0] right
);

reg cen_n, rst_n;

always @(posedge clk) begin
    cen_n <= ~cen;
    rst_n <= ~rst;
end

IKAOPM u_opm(
    .i_EMUCLK       ( clk   ),
    .i_phiM_PCEN_n  ( cen_n ),
    .i_IC_n         ( rst_n ),
    .o_phi1         (       ),
    .i_CS_n         ( cs_n  ),
    .i_RD_n         ( rd_n  ),
    .i_WR_n         ( wr_n  ),
    .i_A0           ( a0    ),
    .i_D            ( din   ),
    .o_D            ( dout  ),
    .o_D_OE         (       ),
    .o_CT2          ( ct2   ),
    .o_CT1          ( ct1   ),
    .o_IRQ_n        ( irq_n ),
    .o_SH1          (       ),
    .o_SH2          (       ),
    .o_SO           (       ),
    .o_EMU_R_SAMPLE (       ),
    .o_EMU_R_EX     (       ),
    .o_EMU_R        ( right ),
    .o_EMU_L_SAMPLE (       ),
    .o_EMU_L_EX     (       ),
    .o_EMU_L        ( left  )
);

endmodule
