/* SPDX-License-Identifier: GPL-3.0-or-later */
// J3 pins 16,18,20,22; all are inputs. HPS user clock is 100 MHz.
module c96_top(input [3:0] pcm_pins);

wire        clk, hps_reset_n;
wire [31:0] gp_out, gp_in;
reg  [ 3:0] reset_pipe = 4'hf;
wire        rst;

assign rst = reset_pipe[3];

always @(posedge clk) begin
    reset_pipe <= {reset_pipe[2:0],!hps_reset_n};
end

cyclonev_hps_interface_clocks_resets u_clocks(
    .h2f_user0_clk       ( clk         ),
    .h2f_rst_n           ( hps_reset_n ),
    .f2h_warm_rst_req_n  ( 1'b1        ),
    .f2h_cold_rst_req_n  ( 1'b1        ),
    .f2h_dbg_rst_req_n   ( 1'b1        ),
    .f2h_pending_rst_ack ( 1'b1        )
);

cyclonev_hps_interface_mpu_general_purpose u_gp(
    .gp_out ( gp_out ),
    .gp_in  ( gp_in  )
);

c96_capture u_capture(
    .clk    ( clk    ),
    .rst    ( rst    ),
    .pins   ( pcm_pins ),
    .gp_out ( gp_out ),
    .gp_in  ( gp_in  )
);

endmodule
