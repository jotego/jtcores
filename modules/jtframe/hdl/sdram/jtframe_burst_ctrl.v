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
module jtframe_burst_ctrl #(
    parameter AW = 22
)(
    input               rst,
    input               clk,
    input               prog_en,
    input               mode_busy,
    input               rfshing,
    input      [AW-1:0] addr,
    input        [ 1:0] ba,
    input               rd,
    input               wr,
    input       [15:0]  din,
    output              burst_idle,
    output reg   [ 3:0] burst_cmd,
    output reg   [12:0] burst_a,
    output      [ 1:0]  burst_ba,
    output reg   [ 1:0] burst_dqm,
    output reg          burst_dq_oe,
    output reg  [15:0]  burst_dq_out,
    output reg          burst_ack,
    output reg          burst_dst,
    output reg          burst_dok,
    output reg          burst_rdy
);

localparam CMD_PRECHARGE   = 4'b0___0____1____0,
           CMD_ACTIVE      = 4'b0___0____1____1,
           CMD_WRITE       = 4'b0___1____0____0,
           CMD_READ        = 4'b0___1____0____1,
           CMD_STOP        = 4'b0___1____1____0,
           CMD_NOP         = 4'b0___1____1____1;

localparam B_IDLE      = 4'd0,
           B_ACT       = 4'd1,
           B_TRCD1     = 4'd2,
           B_TRCD2     = 4'd3,
           B_WACK      = 4'd4,
           B_WRITE_CMD = 4'd5,
           B_WRITE     = 4'd6,
           B_READ_CMD  = 4'd7,
           B_CL1       = 4'd8,
           B_CL2       = 4'd9,
           B_RDATA     = 4'd10,
           B_STOP      = 4'd11,
           B_TWR1      = 4'd12,
           B_TWR2      = 4'd13,
           B_PRE       = 4'd14,
           B_TRP1      = 4'd15;

localparam COLW = AW == 23 ? 10 : 9;

reg  [ 3:0] burst_st;
reg  [AW-1:0] burst_addr;
reg  [ 1:0] burst_bank_r;
reg         burst_write;
reg         burst_first;
reg         post_write_read_wait;

wire [12:0] burst_row = burst_addr[AW-1:COLW];
wire [COLW-1:0] burst_col = burst_addr[COLW-1:0];
wire [ 9:0] burst_col_a = { {(10-COLW){1'b0}}, burst_col };
wire        page_last = &burst_col;

assign burst_idle = burst_st == B_IDLE;
assign burst_ba = burst_bank_r;

always @(posedge clk) begin
    if( rst ) begin
        burst_st     <= B_IDLE;
        burst_addr   <= {AW{1'b0}};
        burst_bank_r <= 2'd0;
        burst_write  <= 1'b0;
        burst_first  <= 1'b0;
        post_write_read_wait <= 1'b0;
    end else if( !prog_en && !mode_busy && !rfshing ) begin
        case( burst_st )
            B_IDLE: begin
                if( rd | wr ) begin
                    burst_addr   <= addr;
                    burst_bank_r <= ba;
                    burst_write  <= wr;
                    burst_first  <= 1'b1;
                    burst_st     <= B_ACT;
                end
            end
            B_ACT:       burst_st <= B_TRCD1;
            B_TRCD1:     burst_st <= B_TRCD2;
            B_TRCD2:     burst_st <= burst_write ? B_WACK : B_READ_CMD;
            B_WACK:      burst_st <= B_WRITE_CMD;
            B_WRITE_CMD: begin
                burst_first <= 1'b0;
                if( !page_last ) burst_addr <= burst_addr + 1'd1;
                burst_st <= (page_last || !wr) ? B_STOP : B_WRITE;
            end
            B_WRITE: begin
                if( !page_last ) burst_addr <= burst_addr + 1'd1;
                burst_st <= (page_last || !wr) ? B_STOP : B_WRITE;
            end
            B_READ_CMD:  burst_st <= B_CL1;
            B_CL1:       burst_st <= B_CL2;
            B_CL2: begin
                if( post_write_read_wait ) begin
                    post_write_read_wait <= 1'b0;
                    burst_st <= B_CL2;
                end else begin
                    burst_st <= B_RDATA;
                end
            end
            B_RDATA: begin
                burst_first <= 1'b0;
                if( !page_last ) burst_addr <= burst_addr + 1'd1;
                burst_st <= (page_last || !rd) ? B_STOP : B_RDATA;
            end
            B_STOP:      burst_st <= burst_write ? B_TWR1 : B_PRE;
            B_TWR1:      burst_st <= B_TWR2;
            B_TWR2:      burst_st <= B_PRE;
            B_PRE:       burst_st <= B_TRP1;
            B_TRP1: begin
                post_write_read_wait <= burst_write;
                burst_st <= B_IDLE;
            end
            default:     burst_st <= B_IDLE;
        endcase
    end
end

always @(*) begin
    burst_cmd    = CMD_NOP;
    burst_a      = 13'd0;
    burst_dqm    = 2'b00;
    burst_dq_oe  = 1'b0;
    burst_dq_out = din;
    burst_ack    = 1'b0;
    burst_dst    = 1'b0;
    burst_dok    = 1'b0;
    burst_rdy    = 1'b0;
    case( burst_st )
        B_ACT: begin
            burst_cmd = CMD_ACTIVE;
            burst_a   = burst_row;
        end
        B_WACK: begin
            burst_ack = 1'b1;
        end
        B_WRITE_CMD: begin
            burst_cmd   = CMD_WRITE;
            burst_a     = { 2'b00, 1'b0, burst_col_a };
            burst_dq_oe = wr;
            burst_rdy   = page_last || !wr;
        end
        B_WRITE: begin
            if( !wr ) burst_cmd = CMD_STOP;
            burst_dq_oe = wr;
            burst_rdy   = page_last || !wr;
        end
        B_READ_CMD: begin
            burst_cmd = CMD_READ;
            burst_a   = { 2'b00, 1'b0, burst_col_a };
            burst_ack = 1'b1;
        end
        B_RDATA: begin
            burst_dst = burst_first;
            burst_dok = 1'b1;
            burst_rdy = page_last || !rd;
        end
        B_STOP: begin
            burst_cmd = CMD_STOP;
        end
        B_PRE: begin
            burst_cmd = CMD_PRECHARGE;
            burst_a[10] = 1'b0;
        end
        default: begin
        end
    endcase
end

endmodule
