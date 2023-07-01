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
    Date: 7-1-2018 */

// Each read takes 8 clock cycles
// clk should be 8*clk_slow

module jtframe_sdram(
    input               rst,
    input               clk, // same as game core
    // Game interface
    output              loop_rst,
    input               read_req,    // read strobe
    output reg  [31:0]  data_read,
    input       [21:0]  sdram_addr,
    input       [ 1:0]  sdram_bank,
    output reg          data_rdy,    // output data is valid
    output reg          sdram_ack,
    input               refresh_en,    // enable refresh to happen automatically
    // Write back to SDRAM
    input       [ 1:0]  sdram_wrmask,
    input               sdram_rnw,
    input       [15:0]  data_write,
    // ROM-load interface
    input               downloading,
    input               prog_we,    // strobe
    input               prog_rd,
    input       [21:0]  prog_addr,
    input       [ 7:0]  prog_data,
    input       [ 1:0]  prog_mask,
    input       [ 1:0]  prog_bank,
    // SDRAM interface
    // SDRAM_A[12:11] and SDRAM_DQML/H are controlled in a way
    // that can be joined together thru an OR operation at a
    // higher level. This makes it possible to short the pins
    // of the SDRAM, as done in the MiSTer 128MB module
    inout       [15:0]  SDRAM_DQ,       // SDRAM Data bus 16 Bits
    output reg  [12:0]  SDRAM_A,        // SDRAM Address bus 13 Bits
    output reg          SDRAM_DQML,     // SDRAM Low-byte Data Mask
    output reg          SDRAM_DQMH,     // SDRAM High-byte Data Mask
    output              SDRAM_nWE,      // SDRAM Write Enable
    output              SDRAM_nCAS,     // SDRAM Column Address Strobe
    output              SDRAM_nRAS,     // SDRAM Row Address Strobe
    output              SDRAM_nCS,      // SDRAM Chip Select
    output reg  [ 1:0]  SDRAM_BA,       // SDRAM Bank Address
    output              SDRAM_CKE       // SDRAM Clock Enable
);

localparam  CMD_LOAD_MODE   = 4'b0000, // 0
            CMD_AUTOREFRESH = 4'b0001, // 1
            CMD_PRECHARGE   = 4'b0010, // 2
            CMD_ACTIVATE    = 4'b0011, // 3
            CMD_WRITE       = 4'b0100, // 4
            CMD_READ        = 4'b0101, // 5
            CMD_STOP        = 4'b0110, // 6 Burst terminate
            CMD_NOP         = 4'b0111, // 7
            CMD_INHIBIT     = 4'b1000; // 8

`ifdef JTFRAME_SDRAM_REPACK
localparam REPACK = 1;
`else
localparam REPACK = 0;
`endif

assign SDRAM_CKE  = 1'b1;

reg [15:0] dq_ff, dq_pad;
reg [15:0] dq_ff0;
reg        dq_rdy;

assign SDRAM_DQ = dq_pad;

generate
    if (REPACK==1) begin : data_repacking
        always @(posedge clk) begin
            data_read <= { dq_ff, dq_ff0 };
            data_rdy  <= dq_rdy;
        end
    end else begin : data_transparent
        always @(*) begin
            data_read = { dq_ff, dq_ff0 };
            data_rdy  = dq_rdy;
        end
    end
endgenerate

reg [15:0] dq_out;
reg        write_cycle, read_cycle, hold_bus;
wire       hold_en;

// SDRAM bus held down during idle cycles help prevent errors in some SDRAM MiSTer modules
// MiSTer FPGA doesn't have pull downs, only pull up. The pull up didn't show performance
// improvement
// For a 32MB memory of mine, the difference between holding the bus and not holding it
// means adding at least 6ns of usable shift range: from 3ns to 10ns
`ifdef SIMULATION
`define JTFRAME_NOHOLDBUS
`endif

`ifdef JTFRAME_NOHOLDBUS
assign hold_en = 0;
`else
assign hold_en = 1;
`endif

reg [8:0] col_addr;

reg [3:0] SDRAM_CMD,
    init_cmd; // this is used to reduce the mux depth to SDRAM_CMD
assign {SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } = SDRAM_CMD;

reg [13:0] wait_cnt;
reg [ 7:0] cnt_state;
reg [ 2:0] init_state;
reg       initialize;


assign loop_rst = initialize;

reg writeon, readprog;
//wire refresh_ok = !read_req;
reg refresh_ok;

always @(posedge clk) begin
    writeon  <= downloading && prog_we;
    readprog <= downloading && prog_rd;
end

reg refresh_cycle;
reg [1:0] refresh_sr;

`ifdef JTFRAME_CLK96
// 96 MHz operation
localparam [ 7:0] ST_ZERO   = 8'h1, ST_ONE = 8'h2, ST_TWO = 8'h4, ST_THREE = 8'h8, ST_FIVE = 8'h20, ST_SIX = 8'h40;
localparam [ 7:0] ST_NOP    = 8'b1111_1010;
localparam [13:0] INIT_WAIT = 14'd10_000;
`else
// 48 MHz operation
localparam [ 7:0] ST_ZERO   = 8'h1, ST_ONE = 8'h2, ST_TWO = 8'h2, ST_THREE = 8'h4, ST_FIVE = 8'h8, ST_SIX = 8'h10;
localparam [ 7:0] ST_NOP    = 8'b1111_1100;
localparam [13:0] INIT_WAIT = 14'd5_000;
`endif

always @(posedge clk)
    if( rst ) begin
        // initialization of SDRAM
        SDRAM_CMD     <= CMD_NOP;
        SDRAM_DQMH    <= 1'b0;
        SDRAM_DQML    <= 1'b0;
        SDRAM_A       <= 13'd0;
        init_cmd      <= CMD_NOP;
        wait_cnt      <= INIT_WAIT; // wait for 100us
        initialize    <= 1'b1;
        init_state    <= 3'd0;
        // Main loop
        cnt_state     <= 8'd1; //Starts after the precharge
        dq_rdy        <= 1'b0;
        sdram_ack     <= 1'b0;
        refresh_sr    <=  'd0;
        refresh_ok    <= 1'b0;
        refresh_cycle <= 0;
        write_cycle   <= 1'b0;
        read_cycle    <= 1'b0;
        hold_bus      <= 1'b1;
        SDRAM_BA      <= 2'b0;
        dq_pad        <= 16'hzzzz;
    end else if( initialize ) begin
        dq_pad <= 16'hzzzz;
        if( |wait_cnt ) begin
            wait_cnt <= wait_cnt-14'd1;
            init_cmd  <= CMD_NOP;
            SDRAM_CMD <= init_cmd;
        end else begin
            if(!init_state[2]) init_state <= init_state+3'd1;
            case(init_state)
                3'd0: begin
                    init_cmd  <= CMD_PRECHARGE;
                    SDRAM_A[10]<= 1'b1; // all banks
                    wait_cnt   <= 14'd2;
                end
                3'd1: begin
                    init_cmd <= CMD_AUTOREFRESH;
                    wait_cnt  <= 14'd11;
                end
                3'd2: begin
                    init_cmd <= CMD_LOAD_MODE;
                    SDRAM_A   <= 13'b00_1_00_010_0_001; // CAS Latency = 2, burst = 2
                    `ifdef SIMULATION
                    `ifndef LOADROM
                        // Start directly with burst mode on simulation
                        // if the ROM load process is not being simulated
                        SDRAM_A   <= 12'b00_1_00_010_0_001; // CAS Latency = 2
                    `endif
                    `endif
                    wait_cnt  <= 14'd3;
                end
                3'd3: begin
                    init_cmd  <= CMD_PRECHARGE;
                    SDRAM_A[10]<= 1'b1; // all banks
                    wait_cnt   <= 14'd4;
                end
                3'd4: begin
                    initialize <= 1'b0;
                    cnt_state  <= 8'd1;
                end
                default: begin
                    SDRAM_CMD  <= init_cmd;
                    initialize <= 1'b0;
                end
            endcase
        end
    end else begin
    //////////////////////////////////////////////////////////////////////////////////
    // regular operation
        dq_pad <= (hold_en && hold_bus) ? 16'h0 : 16'hzzzz;
        if( !cnt_state[0] || refresh_ok ||
            (!downloading && read_req  ) || /* when not downloading */
            ( downloading && (writeon || readprog ) ) /* when downloading */) begin
                cnt_state <= { cnt_state[6:0], cnt_state[7] };
        end
        if( (cnt_state & ST_NOP)!=8'b0 ) begin
            SDRAM_CMD <= CMD_NOP;
        end
        if( cnt_state == ST_ZERO ) begin // activate or refresh
            dq_out         <= downloading ? { prog_data, prog_data } : data_write;
            write_cycle    <= 0;
            read_cycle     <= 0;
            refresh_cycle  <= 0;
            hold_bus       <= 1;
            dq_rdy         <= 0;
            {SDRAM_DQMH, SDRAM_DQML } <= 2'b00;
            begin
                SDRAM_CMD <= CMD_NOP;
                if( writeon || readprog ) begin // ROM downloading
                    SDRAM_CMD <= CMD_ACTIVATE;
                    { SDRAM_A, col_addr } <= prog_addr;
                    SDRAM_BA      <= prog_bank;
                    refresh_cycle <= 1'b0;
                    write_cycle   <=  writeon;
                    read_cycle    <= ~writeon;
                    refresh_sr    <= 2'd0;
                    refresh_ok    <= 0;
                    sdram_ack     <= 1;
                end
                else if( (read_req || refresh_ok) ) begin // regular use
                    SDRAM_CMD <=
                        !read_req ? CMD_AUTOREFRESH : CMD_ACTIVATE;
                    { SDRAM_A, col_addr } <= sdram_addr;
                    SDRAM_BA      <= sdram_bank;
                    refresh_cycle <= !read_req;
                    read_cycle    <= read_req && sdram_rnw;
                    sdram_ack     <= read_req;
                    write_cycle   <= read_req && !sdram_rnw;
                    refresh_sr    <= 2'd0;
                    refresh_ok    <= 0;
                end
                else begin
                    if( refresh_en )
                        { refresh_ok, refresh_sr } <=  { refresh_sr, 1'b1 };
                    else begin
                        refresh_sr <= 2'd0;
                        refresh_ok <= 0;
                    end
                end
            end
        end
        if( cnt_state == ST_ONE ) begin
            sdram_ack <= 1'b0;
        end
        if ( cnt_state == ST_TWO ) begin // set read/write
            // sdram_ack     <= 1'b0;
            SDRAM_A[12:9] <= 4'b0010; // auto precharge;
            SDRAM_A[ 8:0] <= col_addr;
            {SDRAM_DQMH, SDRAM_DQML } <= write_cycle ?
                ( downloading ? prog_mask : sdram_wrmask )
                : 2'b00; // reads always take the two bytes in
            SDRAM_CMD   <= write_cycle ? CMD_WRITE :
                refresh_cycle ? CMD_NOP : CMD_READ;
            dq_rdy      <= 1'b0;
            if( write_cycle ) dq_pad <= dq_out;
            if( read_cycle ) hold_bus <= 1'b0;
        end
        if ( cnt_state == ST_FIVE ) begin
            if( read_cycle) begin
                dq_ff <= SDRAM_DQ;
            end
            if( write_cycle ) begin
                dq_rdy      <= 1'b1;
                write_cycle <= 1'b0;
            end
        end
        if( cnt_state == ST_SIX ) begin
            dq_rdy<=1'b0; // in case previous state set it.
            if( read_cycle) begin
                dq_ff0   <= dq_ff;
                dq_ff    <= SDRAM_DQ;
                dq_rdy   <= 1'b1;   // data_ready marks that new data is ready
                hold_bus <= 1'b1;
                cnt_state<= 8'b1;
            end
            if( write_cycle )   cnt_state <= ST_ZERO;
            if( refresh_cycle ) cnt_state <= ST_ZERO;
        end
    end
endmodule