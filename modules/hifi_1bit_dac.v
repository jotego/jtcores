// Sent by Frederic REQUIN, thanks!

// This module is a third order delta/sigma modulator
// It uses no multiply only shifts by 1, 2 or 13
// There are only 7 adders used, it takes around 110 LUTs
module hifi_1bit_dac
(
  input         reset,
  input         clk,
  input         clk_ena,
  input  [19:0] pcm_in,
  output reg    dac_out
);

// ======================================
// ============== Stage #1 ==============
// ======================================
wire [23:0] w_data_in_p0;
wire [23:0] w_data_err_p0;
wire [23:0] w_data_int_p0;
reg  [23:0] r_data_fwd_p1;

// PCM input extended to 24 bits
assign w_data_in_p0  = { {4{pcm_in[19]}}, pcm_in };

// Error between the input and the quantizer output
assign w_data_err_p0 = w_data_in_p0 - w_data_qt_p2;

// First integrator adder
assign w_data_int_p0 = { {3{w_data_err_p0[23]}}, w_data_err_p0[22:2] } // Divide by 4
                     + r_data_fwd_p1;

// First integrator forward delay
always @(posedge reset or posedge clk)
  if (reset)
    r_data_fwd_p1 <= 24'd0;
  else if (clk_ena)
    r_data_fwd_p1 <= w_data_int_p0;

// ======================================
// ============== Stage #2 ==============
// ======================================
wire [23:0] w_data_fb1_p1;
wire [23:0] w_data_fb2_p1;
wire [23:0] w_data_lpf_p1;
reg  [23:0] r_data_lpf_p2;

// Feedback from the quantizer output
assign w_data_fb1_p1 = { {3{r_data_fwd_p1[23]}}, r_data_fwd_p1[22:2] } // Divide by 4
                     - { {3{w_data_qt_p2[23]}},  w_data_qt_p2[22:2] }; // Divide by 4

// Feedback from the third stage
assign w_data_fb2_p1 = w_data_fb1_p1
                     - { {14{r_data_fwd_p2[23]}}, r_data_fwd_p2[22:13] }; // Divide by 8192

// Low pass filter
assign w_data_lpf_p1 = w_data_fb2_p1 + r_data_lpf_p2;

// Low pass filter feedback delay
always @(posedge reset or posedge clk)
  if (reset)
    r_data_lpf_p2 <= 24'd0;
  else if (clk_ena)
    r_data_lpf_p2 <= w_data_lpf_p1;

// ======================================
// ============== Stage #3 ==============
// ======================================
wire [23:0] w_data_fb3_p1;
wire [23:0] w_data_int_p1;
reg  [23:0] r_data_fwd_p2;

// Feedback from the quantizer output
assign w_data_fb3_p1 = { {2{w_data_lpf_p1[23]}}, w_data_lpf_p1[22:1] } // Divide by 2
                     - { {2{w_data_qt_p2[23]}},  w_data_qt_p2[22:1] }; // Divide by 2

// Second integrator adder
assign w_data_int_p1 = w_data_fb3_p1 + r_data_fwd_p2;

// Second integrator forward delay
always @(posedge reset or posedge clk)
  if (reset)
    r_data_fwd_p2 <= 24'd0;
  else if (clk_ena)
    r_data_fwd_p2 <= w_data_int_p1;

// =====================================
// ========== 1-bit quantizer ==========
// =====================================
wire [23:0] w_data_qt_p2;

assign w_data_qt_p2 = (r_data_fwd_p2[23]) ? 24'hF00000 : 24'h100000;

always @(posedge reset or posedge clk)
  if (reset)
    dac_out <= 1'b0;
  else if (clk_ena)
    dac_out <= ~r_data_fwd_p2[23];

endmodule
