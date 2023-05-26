/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 19-3-2023 */

module jt95c061_timer(
    input                 rst,
    input                 clk,
    input           [3:0] clk_muxin,
    input           [1:0] clk_muxsel,
    input           [3:0] ff_ctrl,
    input           [7:0] cntmax,
    input                 run,
    input                 daisy_over,
    output reg            over,
    output reg            tout
);

wire       tclk;
reg        tclk_l;
reg  [7:0] tcnt, nx_tcnt;

assign tclk = clk_muxin[clk_muxsel];

always @* begin
    nx_tcnt = tcnt + 1'd1;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        tout   <= 0;
        tcnt   <= 0;
        over   <= 0;
    end else begin
        tclk_l <= tclk;
        over <= 0;
        if( tclk & ~tclk_l ) begin
            if( nx_tcnt == cntmax ) begin
                over <= 1;
                tcnt <= 0;
            end else begin
                tcnt   <= nx_tcnt;
            end
        end
        if( !run ) tcnt <= 0;
        case( ff_ctrl[3:2] )
            0: tout <= ~tout;
            1: tout <= 1;
            2: tout <= 0;
            default:
                if( ff_ctrl[1] && (ff_ctrl[0] ? over : daisy_over) )
                    tout <= ~tout;
        endcase
    end
end

endmodule