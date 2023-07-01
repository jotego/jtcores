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

module jtframe_sdram64_rfsh #(parameter HF=1, RFSHCNT=9)
(
    input               rst,
    input               clk,

    input               start,
    output   reg        br,
    input               bg,
    input               noreq,
    output   reg        rfshing,
    output   reg  [3:0] cmd,
    output   reg        help,
    output       [12:0] sdram_a
);

// Frequency limits before getting a tRFC error
// HF=0 -> 60MHz  (16.67ns)
// HF=1 -> 100MHz (10ns)

localparam STW  = 3+7-(HF==1? 0 : 4),
           RFRSH= HF?2:1;

localparam CW=6;
localparam [STW-1:0] ONE=1;

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

`ifdef SIMULATION
initial begin
    if( RFSHCNT >= (1<<CW)-1 ) begin
        $display("ERROR: RFSHCNT is too large for the size of CW (%m)");
        $finish;
    end
end
`endif

assign sdram_a = 13'h400;   // used for precharging all banks

reg  [CW-1:0] cnt;
reg [STW-1:0] st;
reg           last_start;
wire   [CW:0] next_cnt;

assign next_cnt = {1'b0, cnt} + RFSHCNT[CW-1:0];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st      <= 1;
        cmd     <= CMD_NOP;
        cnt     <= 0;
        br      <= 0;
        rfshing <= 0;
        help    <= 0;
    end else begin
        // Forces a refresh if we have built up too much debt
        if( next_cnt[CW] )
            help <= 1;
        if( next_cnt[CW:CW-1]==0 ) // at least half the debt must go
            help <= 0;

        last_start <= start;
        if( start && !last_start ) begin
            cnt <= help ? {CW{1'b1}} : next_cnt[CW-1:0]; // carry over from previous "frame"
        end
        if( cnt!=0 && !rfshing ) begin
            br  <= 1;
            st  <= 1;
        end
        if( bg ) begin
            br      <= 0;
            rfshing <= 1;
        end
        if( rfshing || bg ) begin
            st <= { st[STW-2:0], st[STW-1] };
        end
        if( st[STW-1] ) begin
            if( cnt!=0 ) begin
                cnt <= cnt - 1'd1;
                if( !noreq ) begin
                    rfshing <= 0;
                end else  begin
                    st <= ONE << RFRSH; // do another refresh cycle as there are no requests
                end
            end else begin
                rfshing <= 0;
            end
        end
        cmd <= st[0] ? CMD_PRECHARGE : ( st[RFRSH] ? CMD_REFRESH : CMD_NOP );
    end
end

endmodule