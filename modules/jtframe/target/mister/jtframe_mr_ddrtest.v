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
    Date: 7-3-2019 */

// This module can be used to experiment with the DDRAM
// in Signal Tap. It reads and writes and the data can
// be seen come through

module jtframe_mr_ddrtest(
    input             clk,
    input             rst,
    input      [ 7:0] debug_bus,
    input             hs,

    output            ddram_clk,
    input             ddram_busy,
    output reg [ 7:0] ddram_burstcnt,
    output     [31:3] ddram_addr,
    input      [63:0] ddram_dout,
    input             ddram_dout_ready,
    output reg        ddram_rd,
    output reg [63:0] ddram_din,
    output reg [ 7:0] ddram_be,
    output reg        ddram_we,
    output reg [ 7:0] st_dout
);

reg hsl, busy, wrcycle, ddram_busyl;
reg [7:0] din_cnt, cnt, line;

assign ddram_clk = clk;
assign ddram_addr = { 4'd3, line, 17'd0 };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hsl      <= 0;
        busy     <= 0;
        ddram_be <= 0;
        ddram_rd <= 0;
        ddram_we <= 0;
        din_cnt  <= 0;
        cnt      <= 0;
        st_dout  <= 0;
        line     <= 0;
        ddram_din      <= 0;
        ddram_busyl    <= 0;
        ddram_burstcnt <= 0;
    end else begin
        hsl <= hs;
        ddram_busyl <= ddram_busy;
        case( debug_bus[7:6] )
            0: st_dout <= wrcycle ? ddram_din[ 7:0] : ddram_dout[ 7:0];
            1: st_dout <= wrcycle ? ddram_din[15:8] : ddram_dout[15:8];
            2: st_dout <= { 3'd0, ddram_dout_ready, 3'd0, ddram_busyl };
            3: st_dout <= din_cnt;
        endcase
        if( hs && !hsl && !busy ) begin
            cnt             <= 0;
            din_cnt         <= cnt;
            line            <= line+1'd1;
            busy            <= 1;
            wrcycle         <= ~wrcycle;
            ddram_rd        <=  wrcycle;
            ddram_we        <= ~wrcycle;
            ddram_din         <= 0;
            ddram_din[15:8]   <= line;
            // 0, 7
            ddram_burstcnt    <= 8'h1 << debug_bus[2:0];
            case(debug_bus[4:3])
                0: ddram_be <= 8'b0000_0001;
                1: ddram_be <= 8'b0000_0011;
                2: ddram_be <= 8'b0000_1111;
                3: ddram_be <= 8'b1111_1111;
            endcase
        end
        if( busy && !ddram_busy ) begin
            ddram_rd <= 0;
            if( !wrcycle && ddram_dout_ready ) begin
                cnt <= cnt +1'd1;
                if( cnt==ddram_burstcnt-8'd1 ) begin
                    ddram_rd <= 0;
                    busy <= 0;
                end
            end
            if( wrcycle && ddram_we ) begin
                cnt <= cnt +1'd1;
                ddram_din[7:0] <= ddram_din[7:0] + 1'd1;
                if( cnt==ddram_burstcnt-8'd1 ) begin
                    ddram_we <= 0;
                    busy <= 0;
                end
            end
        end
    end
end

endmodule