/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 20-3-2026 */

// Two-stage output pipeline.
// Stage 1 (fabric registers) captures sel_* near the SDRAM controller FFs
// (X46_Y19). Stage 2 (DDIO registers, via FAST_OUTPUT_REGISTER in sys.tcl)
// sits at the IO pads (X50_Y0). The long routing hop between them gets a
// full clock cycle as a clean register-to-register transfer.
//
// DONT_RETIME on the Stage-1 fabric registers prevents Quartus register
// retiming from merging them into the DDIO registers and undoing the
// pipeline.
//
// Simulation and synthesis use the same command/address/handshake latency.
// The only Verilator-specific behavior is that write data is exposed through
// sdram_din instead of driving the bidirectional SDRAM_DQ pad.

/* verilator coverage_off */
module jtframe_burst_io #(
    parameter MISTER = 1
)(
    input               rst,
    input               clk,
    inout      [15:0]   sdram_dq,
`ifdef VERILATOR
    output reg [15:0]   sdram_din,
`endif
    output reg [12:0]   sdram_a,
    output reg [ 1:0]   sdram_ba,
    output              sdram_dqml,
    output              sdram_dqmh,
    output reg          sdram_nwe,
    output reg          sdram_ncas,
    output reg          sdram_nras,
    output reg          sdram_ncs,
    output              sdram_cke,
    output reg [15:0]   dout,
    output reg          ack,
    output reg          dst,
    output reg          dok,
    output reg          rdy,
    output reg          prog_ack,
    output reg          prog_dst,
    output reg          prog_dok,
    output reg          prog_rdy,
    input               next_dq_oe,
    input      [15:0]   next_dq,
    input               sel_act,
    input               sel_chip,
    input       [3:0]   sel_cmd,
    input      [12:0]   sel_a,
    input       [1:0]   sel_ba,
    input       [1:0]   sel_dqm,
    input               sel_ack,
    input               sel_dst,
    input               sel_dok,
    input               sel_rdy,
    input               sel_prog_ack,
    input               sel_prog_dst,
    input               sel_prog_dok,
    input               sel_prog_rdy
);

reg [1:0] dqm;
assign {sdram_dqmh, sdram_dqml} = MISTER ? sdram_a[12:11] : dqm;
assign sdram_cke = 1'b1;

`ifndef VERILATOR
reg [15:0] dq_pad;
assign sdram_dq = dq_pad;
`endif

// Stage 1: fabric pipeline registers with DONT_RETIME to prevent
// Quartus from merging them into the DDIO output registers.
(* preserve *) reg [3:0]  sel_cmd_r;
(* preserve *) reg [12:0] sel_a_r;
(* preserve *) reg [ 1:0] sel_ba_r;
(* preserve *) reg [ 1:0] sel_dqm_r;
(* preserve *) reg        sel_act_r;
(* preserve *) reg        sel_chip_r;
(* preserve *) reg        sel_ack_r;
(* preserve *) reg        sel_dst_r;
(* preserve *) reg        sel_dok_r;
(* preserve *) reg        sel_rdy_r;
(* preserve *) reg        sel_prog_ack_r;
(* preserve *) reg        sel_prog_dst_r;
(* preserve *) reg        sel_prog_dok_r;
(* preserve *) reg        sel_prog_rdy_r;
(* preserve *) reg        next_dq_oe_r;
(* preserve *) reg [15:0] next_dq_r;
// Stage 1: capture inputs at the IO module boundary
always @(posedge clk) begin
    if( rst ) begin
        sel_cmd_r      <= 4'b0111;
        sel_a_r        <= 13'd0;
        sel_ba_r       <= 2'd0;
        sel_dqm_r      <= 2'b00;
        sel_act_r      <= 1'b0;
        sel_chip_r     <= 1'b0;
        sel_ack_r      <= 1'b0;
        sel_dst_r      <= 1'b0;
        sel_dok_r      <= 1'b0;
        sel_rdy_r      <= 1'b0;
        sel_prog_ack_r <= 1'b0;
        sel_prog_dst_r <= 1'b0;
        sel_prog_dok_r <= 1'b0;
        sel_prog_rdy_r <= 1'b0;
        next_dq_oe_r   <= 1'b0;
        next_dq_r      <= 16'd0;
    end else begin
        sel_cmd_r      <= sel_cmd;
        sel_a_r        <= sel_a;
        sel_ba_r       <= sel_ba;
        sel_dqm_r      <= sel_dqm;
        sel_act_r      <= sel_act;
        sel_chip_r     <= sel_chip;
        sel_ack_r      <= sel_ack;
        sel_dst_r      <= sel_dst;
        sel_dok_r      <= sel_dok;
        sel_rdy_r      <= sel_rdy;
        sel_prog_ack_r <= sel_prog_ack;
        sel_prog_dst_r <= sel_prog_dst;
        sel_prog_dok_r <= sel_prog_dok;
        sel_prog_rdy_r <= sel_prog_rdy;
        next_dq_oe_r   <= next_dq_oe;
        next_dq_r      <= next_dq;
    end
end

// Stage 2: DDIO output registers driven from pipeline copies.
// These get packed into DDIO cells by FAST_OUTPUT_REGISTER in sys.tcl.
// Separate always block prevents Quartus from merging Stage 1 into them.
always @(posedge clk) begin
    if( rst ) begin
        sdram_nwe  <= 1'b1;
        sdram_ncas <= 1'b1;
        sdram_nras <= 1'b1;
        sdram_ncs  <= 1'b1;
        sdram_ba   <= 2'd0;
        sdram_a    <= 13'd0;
        dqm        <= 2'b00;
        ack        <= 1'b0;
        dst        <= 1'b0;
        dok        <= 1'b0;
        rdy        <= 1'b0;
        prog_ack   <= 1'b0;
        prog_dst   <= 1'b0;
        prog_dok   <= 1'b0;
        prog_rdy   <= 1'b0;
        dout       <= 16'd0;
`ifdef VERILATOR
        sdram_din  <= 16'd0;
`else
        dq_pad     <= 16'hzzzz;
`endif
    end else begin
        {sdram_ncs, sdram_nras, sdram_ncas, sdram_nwe} <= { sel_cmd_r[3] ^ sel_chip_r, sel_cmd_r[2:0] };
        sdram_ba <= sel_ba_r;
        dqm      <= sel_dqm_r;
        ack      <= sel_ack_r;
        dst      <= sel_dst_r;
        dok      <= sel_dok_r;
        rdy      <= sel_rdy_r;
        prog_ack <= sel_prog_ack_r;
        prog_dst <= sel_prog_dst_r;
        prog_dok <= sel_prog_dok_r;
        prog_rdy <= sel_prog_rdy_r;
        dout     <= sdram_dq;

        if( MISTER ) begin
            sdram_a[10: 0] <= sel_a_r[10:0];
            sdram_a[12:11] <= sel_act_r ? sel_a_r[12:11] : sel_dqm_r;
        end else begin
            sdram_a <= sel_a_r;
        end

`ifdef VERILATOR
        sdram_din <= next_dq_r;
`else
        dq_pad <= next_dq_oe_r ? next_dq_r : 16'hzzzz;
`endif
    end
end

endmodule
