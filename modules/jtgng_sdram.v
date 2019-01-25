/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 7-1-2018 */


module jtgng_sdram(
    input               rst,
    input               clk, // 96MHz = 32 * 6 MHz -> CL=2  
    output reg          loop_rst,  
    input               loop_start,
    input               autorefresh,
    output reg  [15:0]  data_read,
    input       [21:0]  sdram_addr,
    // ROM-load interface
    input               downloading,
    input       [24:0]  romload_addr,
    input       [15:0]  romload_data,
    // SDRAM interface
    inout       [15:0]  SDRAM_DQ,       // SDRAM Data bus 16 Bits
    output reg  [12:0]  SDRAM_A,        // SDRAM Address bus 13 Bits
    output              SDRAM_DQML,     // SDRAM Low-byte Data Mask
    output              SDRAM_DQMH,     // SDRAM High-byte Data Mask
    output  reg         SDRAM_nWE,      // SDRAM Write Enable
    output  reg         SDRAM_nCAS,     // SDRAM Column Address Strobe
    output  reg         SDRAM_nRAS,     // SDRAM Row Address Strobe
    output  reg         SDRAM_nCS,      // SDRAM Chip Select
    output      [ 1:0]  SDRAM_BA,       // SDRAM Bank Address
    output              SDRAM_CKE       // SDRAM Clock Enable     
);

localparam  CMD_LOAD_MODE   = 4'b0000, // 0 
            CMD_AUTOREFRESH = 4'b0001, // 1 
            CMD_PRECHARGE   = 4'b0010, // 2
            CMD_ACTIVATE    = 4'b0011, // 3 
            CMD_WRITE       = 4'b0100, // 4
            CMD_READ        = 4'b0101, // 5
            CMD_STOP        = 4'b0110, // 6
            CMD_NOP         = 4'b0111, // 7
            CMD_INHIBIT     = 4'b1000; // 8


localparam  INITIALIZE    = 4'd15, 
            WAIT          = 4'd0, 
            SET_PRECHARGE = 4'd1, 
            ACTIVATE      = 4'd2,
            SET_READ      = 4'd3, 
            READ          = 4'd4, 
            AUTO_REFRESH1 = 4'd5,
            SET_PRECHARGE_WR = 4'd8, 
            ACTIVATE_WR   = 4'd9,
            SET_WRITE     = 4'd10,
            SYNC_START    = 4'd6;

parameter PRECHARGE_WAIT = 4'd0, ACTIVATE_WAIT=4'd0, CL_WAIT=4'd1;

assign SDRAM_DQMH = 1'b0;
assign SDRAM_DQML = 1'b0;
assign SDRAM_BA   = 2'b0;
assign SDRAM_CKE  = 1'b1;

reg SDRAM_WRITE;
reg [15:0] write_data;
assign SDRAM_DQ =  SDRAM_WRITE ? write_data : 16'hzzzz;            

reg [3:0] state, next, init_state;
reg [3:0] wait_cnt;
reg pre_loop_rst;

localparam col_w = 9, row_w = 13;
localparam addr_w = 13, data_w = 16;

wire [addr_w-1:0] row_addr = sdram_addr[addr_w+col_w-1:col_w];
wire [col_w-1:0]  col_addr = sdram_addr[col_w-1:0];
reg [col_w-1:0]   romload_col;


`ifdef SIMULATION
integer sdram_writes = 0;
wire [3:0] mem_cmd = { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE };
wire [(row_w+col_w-1):0] full_addr = {row_addr,col_addr};
wire [(row_w+col_w-1-12):0] top_addr = full_addr>>12;
`endif


// reg H2edge;
// reg [1:0] H2s;
// 
// always @(posedge clk) begin
//     H2s <= { H2s[0], H2};
//     H2edge <= H2s[1] && !H2s[0];
// end

always @(posedge clk)
    if( rst ) begin
        state <= INITIALIZE;
        init_state <= 4'd0;
        { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_INHIBIT;
        // { wait_cnt, SDRAM_A } <= 17'd9800;
        { wait_cnt, SDRAM_A } <= 17'd9743;
        loop_rst     <= 1'b1;
        pre_loop_rst <= 1'b1;
        SDRAM_WRITE<= 1'b0;
    end else  begin
    case( state )
        default: state <= SET_PRECHARGE;
        INITIALIZE: begin
            case(init_state)
                4'd0: begin // wait for 100us
                    { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_NOP;
                    { wait_cnt, SDRAM_A } <= { wait_cnt, SDRAM_A }-1'b1;
                    if( |{ wait_cnt, SDRAM_A }==1'b0 ) 
                        init_state <= init_state+4'd1;
                    end
                4'd1: begin
                    { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_PRECHARGE;
                    SDRAM_A[10]<=1'b1; // all banks
                    wait_cnt   <= PRECHARGE_WAIT;
                    state      <= WAIT;
                    next       <= INITIALIZE;
                    init_state <= init_state+4'd1;
                    end
                4'd2,4'd3: begin
                    { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_AUTOREFRESH;
                    wait_cnt   <= 4'd10;
                    state      <= WAIT;
                    next       <= INITIALIZE;
                    init_state <= init_state+4'd1;
                    end
                4'd4: begin
                    { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_LOAD_MODE;
                    SDRAM_A      <= CL_WAIT == 1 ?
                        13'b00_1_00_010_0_000: // CAS Latency = 2
                        13'b00_1_00_011_0_000; // CAS Latency = 3
                    wait_cnt     <= 4'd2;
                    state        <= WAIT;
                    next         <= SET_PRECHARGE;
                    pre_loop_rst <= 1'b0;
                    `ifdef SIMULATION
                    $display("SDRAM initialization ready");
                    `endif
                    // next <= INITIALIZE;
                    // init_state <= init_state+4'd1;
                    end
                4'd5: begin // wait to rd_state zero
                    if( loop_start ) begin
                        state <=SET_PRECHARGE;
                        end
                    end
                default: init_state<=4'd0;
            endcase
            end
        SET_PRECHARGE: begin
            { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_PRECHARGE;
            SDRAM_A[10]<=1'b1; // all banks
            wait_cnt <= PRECHARGE_WAIT;
            state    <= WAIT;
            next     <= autorefresh ? AUTO_REFRESH1 : ACTIVATE;     
            // Clear WRITE state:
            SDRAM_WRITE <= 1'b0;
            end
        WAIT: begin
            { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_NOP;
            if( wait_cnt==4'd0 ) begin
                state    <= next;
                loop_rst <= pre_loop_rst; 
            end
            wait_cnt <= wait_cnt-4'b1;
            end
        ACTIVATE: begin 
            { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_ACTIVATE;
            SDRAM_A  <= row_addr;
            wait_cnt <= ACTIVATE_WAIT;
            next     <= SET_READ;
            state    <= WAIT;
            end     
        SET_READ:begin
            { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_READ;
            wait_cnt <= CL_WAIT-4'd1;
            state    <= WAIT;
            next     <= READ;
            SDRAM_A  <= { {(addr_w-col_w){1'b0}}, col_addr};
            end     
        READ: begin
            if( downloading )
                state <=  SET_PRECHARGE_WR;
            else begin
                wait_cnt  <= 4'd0; // waste one cycle to synchronize with jtgng_rom
                state     <= WAIT;
                next      <= SET_PRECHARGE;
                data_read <= SDRAM_DQ;                
            end
            end
        SYNC_START:
            if( loop_start ) state <= SET_PRECHARGE;
        AUTO_REFRESH1: begin
                { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_AUTOREFRESH;
                wait_cnt <= 4'd5;
                state    <= WAIT;
                next     <= SYNC_START;
            end
        // Write states
        SET_PRECHARGE_WR: begin
            { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_PRECHARGE;
            SDRAM_A[10]<=1'b1; // all banks
            wait_cnt <= PRECHARGE_WAIT;
            state <= WAIT;
            next <= ACTIVATE_WR;
            end
        ACTIVATE_WR: begin 
            { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_ACTIVATE;
            // Address and data are captured at this stage
            { SDRAM_A, romload_col } <= romload_addr[21:0];
            write_data <= romload_data;         
            wait_cnt <= ACTIVATE_WAIT;
            next  <= SET_WRITE;
            state <= WAIT;
            end     
        SET_WRITE: if( downloading) begin
            { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_WRITE;
            SDRAM_WRITE <= 1'b1;
            wait_cnt <= PRECHARGE_WAIT + 3;
            state <= WAIT;
            next  <= ACTIVATE_WR;
            SDRAM_A[8:0] <= romload_col;
            SDRAM_A[12:9] <= 4'b10; // auto precharge;
            `ifdef SIMULATION
                sdram_writes = sdram_writes + 2;
            `endif
            end     
            else begin
                state <= WAIT;
                next  <= SYNC_START;
            end
    endcase // state
    end

endmodule // jtgng_sdram