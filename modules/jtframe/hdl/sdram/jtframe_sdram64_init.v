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
    Version: 1.0
    Date: 29-4-2021 */

module jtframe_sdram64_init #(parameter
    HF      =1,
    BURSTLEN=64
) (
    input               rst,
    input               clk,

    output   reg        init,
    output   reg  [3:0] cmd,
    output   reg [12:0] sdram_a
);

localparam [13:0] INIT_WAIT = HF ? 14'd10_000 : 14'd5_000; // 100us for 96MHz/48MHz

//                             /CS /RAS /CAS /WE
localparam CMD_LOAD_MODE   = 4'b0___0____0____0, // 0
           CMD_REFRESH     = 4'b0___0____0____1, // 1
           CMD_PRECHARGE   = 4'b0___0____1____0, // 2
           CMD_ACTIVE      = 4'b0___0____1____1, // 3
           CMD_WRITE       = 4'b0___1____0____0, // 4
           CMD_READ        = 4'b0___1____0____1, // 5
           CMD_STOP        = 4'b0___1____1____0, // 6 Burst terminate
           CMD_NOP         = 4'b0___1____1____1, // 7
           CMD_INHIBIT     = 4'b1___0____0____0; // 8

// initialization signals
reg [13:0] wait_cnt;
reg [ 2:0] init_st;
reg [ 3:0] init_cmd;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        // initialization loop
        init     <= 1;
        wait_cnt <= INIT_WAIT; // wait for 100us
        init_st  <= 3'd0;
        init_cmd <= CMD_NOP;
        // SDRAM pins
        cmd      <= CMD_NOP;
        sdram_a  <= 13'd0;
    end else if( init ) begin
        if( |wait_cnt ) begin
            wait_cnt <= wait_cnt-14'd1;
            init_cmd <= CMD_NOP;
            cmd      <= init_cmd;
        end else begin
            sdram_a  <= 13'd0;
            if(!init_st[2]) init_st <= init_st+3'd1;
            case(init_st)
                3'd0: begin
                    init_cmd   <= CMD_PRECHARGE;
                    sdram_a[10]<= 1; // all banks
                    wait_cnt   <= 14'd2;
                end
                3'd1: begin
                    init_cmd <= CMD_REFRESH;
                    wait_cnt <= 14'd11;
                end
                3'd2: begin
                    init_cmd <= CMD_REFRESH;
                    wait_cnt <= 14'd11;
                end
                3'd3: begin
                    init_cmd <= CMD_LOAD_MODE;
                    sdram_a  <= {10'b00_1_00_010_0,BURSTLEN==64?3'b010:(BURSTLEN==32?3'b001:3'b000)}; // CAS Latency = 2, burst = 1-4
                    wait_cnt <= 14'd3;
                end
                3'd4: begin
                    init <= 0;
                end
                default: begin
                    cmd  <= init_cmd;
                    init <= 0;
                end
            endcase
        end
    end
end

endmodule