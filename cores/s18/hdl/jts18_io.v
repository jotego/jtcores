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
    Date: 30-4-2024 */

// 315-5296 IO controller
// Based on MAME's implementation and PCB schematics

module jts18_io(
    input             rst,
    input             clk,
    input       [5:0] addr,
    input       [7:0] din,
    output reg  [7:0] dout,
    input             we,
    // eight 8-bit ports
    input       [7:0] pa_i, pb_i, pc_i, pd_i,
                      pe_i, pf_i, pg_i, ph_i,
    output      [7:0] pa_o, pb_o, pc_o, pd_o,
                      pe_o, pf_o, pg_o, ph_o,
    // three output pins
    output      [2:0] coin_cnt
);

reg [7:0] pout[0:7];
reg [7:0] dir;
reg [7:0] cnt;

assign pa_o = dir[0] ? pout[0] : pa_i;
assign pb_o = dir[1] ? pout[1] : pb_i;
assign pc_o = dir[2] ? pout[2] : pc_i;
assign pd_o = dir[3] ? pout[3] : pd_i;
assign pe_o = dir[4] ? pout[4] : pe_i;
assign pf_o = dir[5] ? pout[5] : pf_i;
assign pg_o = dir[6] ? pout[6] : pg_i;
assign ph_o = dir[7] ? pout[7] : ph_i;

assign coin_cnt[1:0] = cnt[1:0];
assign coin_cnt[2]   = cnt[3] ? 1'b0 : cnt[2]; // should output a clock when cnt[3] is high
    // d4,5: CNT2 clock divider (0= CLK/4, 1= CLK/8, 2= CLK/16, 3= CLK/2)
    // d6,7: CKOT clock divider (0= CLK/4, 1= CLK/8, 2= CLK/16, 3= CLK/2)
    // TODO..

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pout[0] <= 0; pout[1] <= 0; pout[2] <= 0; pout[3] <= 0;
        pout[4] <= 0; pout[5] <= 0; pout[6] <= 0; pout[7] <= 0;
        dir     <= 0; // ports set as input
    end else begin
        case(addr)
            0: dout <= pa_o;
            1: dout <= pb_o;
            2: dout <= pc_o;
            3: dout <= pd_o;
            4: dout <= pe_o;
            5: dout <= pf_o;
            6: dout <= pg_o;
            7: dout <= ph_o;
            8: dout <= 'S';
            9: dout <= 'E';
           10: dout <= 'G';
           11: dout <= 'A';
           12,13: dout <= cnt;
           14,15: dout <= dir;
        endcase
        if( we ) casez(addr)
            4'b0???: if(dir[addr[2:0]]) pout[addr[2:0]] <= din;
            4'he: cnt <= din;
            4'hf: dir <= din;
            default:;
        endcase
    end
end

endmodule