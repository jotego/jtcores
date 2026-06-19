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
module jtframe_burst_mode #(
    parameter PROG_LEN = 64,
              XL       = 0
)(
    input               rst,
    input               clk,
    input               init,
    input               prog_en,
    input               rfshing,
    input               pre_idle,
    input               burst_idle,
    output reg          prog_rst,
    output reg          rfsh_rst,
    output              mode_busy,
    output reg          mode_chip,
    output reg  [ 3:0]  mode_cmd,
    output reg  [12:0]  mode_a
);

localparam CMD_LOAD_MODE = 4'b0___0____0____0,
           CMD_PRECHARGE = 4'b0___0____1____0,
           CMD_NOP       = 4'b0___1____1____1;

localparam MODE_IDLE  = 3'd0,
           MODE_PRE   = 3'd1,
           MODE_TRP1  = 3'd2,
           MODE_TRP2  = 3'd3,
           MODE_CMD   = 3'd4,
           MODE_WAIT1 = 3'd5,
           MODE_WAIT2 = 3'd6;

wire [2:0] prog_bl_code = PROG_LEN == 64 ? 3'b010 :
                          (PROG_LEN == 32 ? 3'b001 : 3'b000);
wire [12:0] mode_prog_a = {10'b00_1_00_010_0, prog_bl_code};
wire [12:0] mode_fullpage_a = 13'b000_0_00_010_0_111;

reg  [2:0] mode_st;
reg        current_fullpage;
wire       want_fullpage = !prog_en;

assign mode_busy = mode_st != MODE_IDLE;

always @(negedge clk) begin
    prog_rst <= ~prog_en | init | rst | mode_busy;
    rfsh_rst <= init | rst;
end

always @(posedge clk) begin
    if( rst ) begin
        mode_st <= MODE_IDLE;
        mode_chip <= 1'b0;
        current_fullpage <= 1'b0;
    end else begin
        case( mode_st )
            MODE_IDLE: begin
                if( !init && (current_fullpage != want_fullpage) &&
                    !rfshing && (prog_en ? pre_idle : burst_idle) ) begin
                    mode_st <= MODE_PRE;
                    mode_chip <= 1'b0;
                end
            end
            MODE_PRE:   mode_st <= MODE_TRP1;
            MODE_TRP1:  mode_st <= MODE_TRP2;
            MODE_TRP2:  mode_st <= MODE_CMD;
            MODE_CMD:   mode_st <= MODE_WAIT1;
            MODE_WAIT1: mode_st <= MODE_WAIT2;
            MODE_WAIT2: begin
                if( XL && !mode_chip ) begin
                    mode_chip <= 1'b1;
                    mode_st   <= MODE_PRE;
                end else begin
                    mode_st <= MODE_IDLE;
                    current_fullpage <= want_fullpage;
                end
            end
            default: mode_st <= MODE_IDLE;
        endcase
    end
end

always @(*) begin
    mode_cmd = CMD_NOP;
    mode_a   = current_fullpage ? mode_fullpage_a : mode_prog_a;
    case( mode_st )
        MODE_PRE: begin
            mode_cmd  = CMD_PRECHARGE;
            mode_a    = 13'd0;
            mode_a[10] = 1'b1;
        end
        MODE_CMD: begin
            mode_cmd = CMD_LOAD_MODE;
            mode_a   = want_fullpage ? mode_fullpage_a : mode_prog_a;
        end
        default: begin
        end
    endcase
end

endmodule
