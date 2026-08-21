/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-4-2021 */
/* verilator coverage_off */
module jtframe_sdram64_init #(parameter
    HF      =1,
    BURSTLEN=64,
    XL      =0
) (
    input               rst,
    input               clk,

    output   reg        init,
    output   reg        chip,
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

always @(posedge clk) begin
    if( rst ) begin
        // initialization loop
        init     <= 1;
        chip     <= 0;
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
                    if( XL && !chip ) begin
                        chip     <= 1;
                        init_st  <= 3'd0;
                        init_cmd <= CMD_NOP;
                        wait_cnt <= 14'd2;
                    end else begin
                        init <= 0;
                    end
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