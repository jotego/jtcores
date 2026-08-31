/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_scroll_vram_lanes(
    input         clk,
    input  [12:0] scrama,
    input  [23:0] vd_in,
    input  [2:0]  rwe_n,
    input  [2:0]  roe_n,
    output [23:0] vd_out
);

(* ramstyle = "M10K, no_rw_check" *) reg [7:0] vram0 [0:8191];
(* ramstyle = "M10K, no_rw_check" *) reg [7:0] vram1 [0:8191];
(* ramstyle = "M10K, no_rw_check" *) reg [7:0] vram2 [0:8191];
reg [7:0] vram0_q, vram1_q, vram2_q;

always @(posedge clk) begin
    if (!rwe_n[0])
        vram0[scrama] <= vd_in[7:0];
    vram0_q <= vram0[scrama];
end

always @(posedge clk) begin
    if (!rwe_n[1])
        vram1[scrama] <= vd_in[15:8];
    vram1_q <= vram1[scrama];
end

always @(posedge clk) begin
    if (!rwe_n[2])
        vram2[scrama] <= vd_in[23:16];
    vram2_q <= vram2[scrama];
end

// The PCB SRAMs share a 24-bit bus, but the FPGA has one explicit owner for
// the three byte lanes.  An inactive lane is therefore driven to zero rather
// than represented by a synthesizer-dependent high-impedance value.  Consumers
// must qualify each lane with the corresponding ROE signal.
assign vd_out[7:0]   = roe_n[0] ? 8'h00 : vram0_q;
assign vd_out[15:8]  = roe_n[1] ? 8'h00 : vram1_q;
assign vd_out[23:16] = roe_n[2] ? 8'h00 : vram2_q;

endmodule
