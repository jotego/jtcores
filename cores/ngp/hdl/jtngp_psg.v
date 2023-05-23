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
    Date: 23-5-2023 */

module jtngp_psg(
    input          rst,
    input          clk,
    input          cen,

    input          r_wn,
    input          cs,
    input    [7:0] din,

    output signed [10:0] snd
);

// _numer (ch_0) is channel square and _n (ch_n) is channel noise
reg         [8:0] ch_0, ch_1, ch_3, ch_n;
reg         [3:0] vol_0, vol_1, vol_2, vol_n;
reg         [9:0] tone_0, tone_1, tone_2;
reg         [2:0] tone_n;

reg         [3:0] reg_sel;

reg               cen16;
reg         [3:0] cnt_cen = 0;


always @(posedge clk) begin
    if( cen ) cen_cnt <= cen_cnt + 1'd1;
    cen16 <= cen_cnt[3:0] == 0 && cen;
    cen4  <= cen_cnt[1:0] == 0 && cen;
end


always @(posedge clk, posedge rst) begin
    if( rst ) begin
         tone0 <= tone1 <= tone2 <= tone_n <= 0;
         vol0  <= vol1  <= vol2  <= vol_n  <= 0;
    end else begin
        if( !cs && !r_wn ) begin
            case( reg_sel )
                3'b000: tone_2 <= ;
                3'b001: vol0   <= din[3:0];
                3'b010: tone_1 <= ;
                3'b011: vol1   <= din[3:0];
                3'b100: tone_0 <= ;
                3'b101: vol2   <= din[3:0];
                3'b110: tone_n <= ;
                3'b111: vol_n  <= din[3:0];
                default: ;
            endcase
        end
    end
end


endmodule