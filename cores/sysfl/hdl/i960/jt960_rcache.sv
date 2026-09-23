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

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 18-9-2026
*/

// on-chip local register cache: 4 frames x 16 registers + frame address
// block RAM, registered read; a whole frame moves in one clock. The read
// lags frame by one clk, absorbed by the >=2 clk cpu_cen spacing

module jt960_rcache(
    input              clk,
    input      [  1:0] frame,
    input              we,
    input      [511:0] din,
    (* preserve *) output reg [511:0] dout,
    input              fa_we,
    input      [ 31:0] fa_din,
    (* preserve *) output reg [ 31:0] fa_dout
);

(* ramstyle = "no_rw_check, M10K" *) reg [511:0] mem[0:3];
(* ramstyle = "no_rw_check, M10K" *) reg [ 31:0] fa [0:3];

always @(posedge clk) begin
    dout    <= mem[frame];
    fa_dout <= fa[frame];
    if( we    ) mem[frame] <= din;
    if( fa_we ) fa[frame]  <= fa_din;
end

endmodule
