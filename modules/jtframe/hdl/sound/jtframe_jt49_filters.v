/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-11-2020 */

module jtframe_jt49_filters(
    input                rst,
    input                clk,
    input         [ 9:0] din0,
    input         [ 9:0] din1,
    input                sample,
    output signed [15:0] dout
);

localparam W=11,WD=16-W;

wire signed [W-1:0] dcrm_snd;
reg         [W-1:0] base_snd;
wire signed [ 15:0] dcrm16 = { dcrm_snd, dcrm_snd[W-2:W-WD-1] };

always @(posedge clk) begin
    if( rst ) begin
        base_snd <= {W{1'd0}};
    end else if(sample) begin
        base_snd <= { {W-10{1'b0}}, din0} + { {W-10{1'b0}}, din1};
    end
end

jtframe_dcrm #(.SW(W)) u_dcrm(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( sample    ),
    .din    ( base_snd  ),
    .dout   ( dcrm_snd  )
);

jtframe_fir #(.KMAX(126),.COEFFS("firjt49.hex")) u_fir(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( sample    ),
    .l_in   ( dcrm16    ),
    .r_in   ( 16'd0     ),
    .l_out  ( dout      ),
    .r_out  (           )
);

endmodule