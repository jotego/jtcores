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
module jtframe_burst_mux(
    input               init,
    input               mode_busy,
    input               rfshing,
    input               prog_en,
    input               prog_wr,
    input      [15:0]   prog_din,
    input       [1:0]   prog_dsn,
    input       [1:0]   prog_ba,
    input       [3:0]   pre_cmd,
    input      [12:0]   pre_a,
    input               pre_ack,
    input               pre_dst,
    input               pre_dok,
    input               pre_rdy,
    input       [3:0]   init_cmd,
    input      [12:0]   init_a,
    input       [3:0]   rfsh_cmd,
    input      [12:0]   rfsh_a,
    input       [3:0]   mode_cmd,
    input      [12:0]   mode_a,
    input       [3:0]   burst_cmd,
    input      [12:0]   burst_a,
    input       [1:0]   burst_ba,
    input       [1:0]   burst_dqm,
    input               burst_dq_oe,
    input      [15:0]   burst_dq_out,
    input               burst_ack,
    input               burst_dst,
    input               burst_dok,
    input               burst_rdy,
    output reg          next_dq_oe,
    output reg [15:0]   next_dq,
    output reg  [3:0]   sel_cmd,
    output reg [12:0]   sel_a,
    output reg  [1:0]   sel_ba,
    output reg  [1:0]   sel_dqm,
    output reg          sel_ack,
    output reg          sel_dst,
    output reg          sel_dok,
    output reg          sel_rdy,
    output reg          sel_prog_ack,
    output reg          sel_prog_dst,
    output reg          sel_prog_dok,
    output reg          sel_prog_rdy
);

always @(*) begin
    next_dq_oe   = 1'b0;
    next_dq      = 16'h0000;
    sel_cmd      = 4'b0111;
    sel_a        = 13'd0;
    sel_ba       = 2'd0;
    sel_dqm      = 2'b00;
    sel_ack      = 1'b0;
    sel_dst      = 1'b0;
    sel_dok      = 1'b0;
    sel_rdy      = 1'b0;
    sel_prog_ack = 1'b0;
    sel_prog_dst = 1'b0;
    sel_prog_dok = 1'b0;
    sel_prog_rdy = 1'b0;

    if( init ) begin
        sel_cmd = init_cmd;
        sel_a   = init_a;
    end else if( mode_busy ) begin
        sel_cmd = mode_cmd;
        sel_a   = mode_a;
    end else if( rfshing ) begin
        sel_cmd = rfsh_cmd;
        sel_a   = rfsh_a;
    end else if( prog_en ) begin
        next_dq_oe   = prog_wr;
        next_dq      = prog_din;
        sel_cmd      = pre_cmd;
        sel_a        = pre_a;
        sel_ba       = prog_ba;
        sel_dqm      = prog_wr ? prog_dsn : 2'b00;
        sel_prog_ack = pre_ack;
        sel_prog_dst = pre_dst;
        sel_prog_dok = pre_dok;
        sel_prog_rdy = pre_rdy;
    end else begin
        next_dq_oe = burst_dq_oe;
        next_dq    = burst_dq_out;
        sel_cmd    = burst_cmd;
        sel_a      = burst_a;
        sel_ba     = burst_ba;
        sel_dqm    = burst_dqm;
        sel_ack    = burst_ack;
        sel_dst    = burst_dst;
        sel_dok    = burst_dok;
        sel_rdy    = burst_rdy;
    end
end

endmodule
