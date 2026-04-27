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
    output              sdram_nwe,
    output              sdram_ncas,
    output              sdram_nras,
    output              sdram_ncs,
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

reg [3:0] cmd;
reg [1:0] dqm;
assign {sdram_ncs, sdram_nras, sdram_ncas, sdram_nwe } = cmd;
assign {sdram_dqmh, sdram_dqml} = MISTER ? sdram_a[12:11] : dqm;
assign sdram_cke = 1'b1;

`ifndef VERILATOR
reg [15:0] dq_pad;
assign sdram_dq = dq_pad;
`endif

always @(posedge clk) begin
    if( rst ) begin
        cmd      <= 4'b0111;
        sdram_ba <= 2'd0;
        sdram_a  <= 13'd0;
        dqm      <= 2'b00;
        ack      <= 1'b0;
        dst      <= 1'b0;
        dok      <= 1'b0;
        rdy      <= 1'b0;
        prog_ack <= 1'b0;
        prog_dst <= 1'b0;
        prog_dok <= 1'b0;
        prog_rdy <= 1'b0;
        dout     <= 16'd0;
`ifndef VERILATOR
        dq_pad   <= 16'hzzzz;
`else
        sdram_din <= 16'd0;
`endif
    end else begin
        dout     <= sdram_dq;
        cmd      <= sel_cmd;
        sdram_ba <= sel_ba;
        dqm      <= sel_dqm;
        ack      <= sel_ack;
        dst      <= sel_dst;
        dok      <= sel_dok;
        rdy      <= sel_rdy;
        prog_ack <= sel_prog_ack;
        prog_dst <= sel_prog_dst;
        prog_dok <= sel_prog_dok;
        prog_rdy <= sel_prog_rdy;

        if( MISTER ) begin
            sdram_a[10: 0] <= sel_a[10:0];
            sdram_a[12:11] <= sel_cmd == 4'b0011 ? sel_a[12:11] :
                              (next_dq_oe ? sel_dqm : 2'b00);
        end else begin
            sdram_a <= sel_a;
        end

`ifndef VERILATOR
        dq_pad <= next_dq_oe ? next_dq : 16'hzzzz;
`else
        sdram_din <= next_dq;
`endif
    end
end

endmodule
