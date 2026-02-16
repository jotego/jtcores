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
    Date: 14-2-2026 */

module jtx1010_acc(
    input               clk, cen,
    input        [ 7:0] cfg,
    input        [ 3:0] ch,
    input        [ 4:0] st,
    input signed [15:0] wav_l, wav_r, pcm_l, pcm_r,
    output reg          sample,
    output reg signed [15:0] snd_l, snd_r, mux_l
);

localparam WAV=1;

reg signed [15:0] mux_r, acc_l=0, acc_r=0;

always_comb begin
    mux_l = cfg[WAV] ? wav_l : pcm_l;
    mux_r = cfg[WAV] ? wav_r : pcm_r;
end

always_ff @(posedge clk) if(cen) begin
    sample <= 0;
    if(st==31) begin
        sample <= 1;
        if(ch==0) begin
            snd_l <= acc_l;
            snd_r <= acc_r;
            acc_l <= mux_l;
            acc_r <= mux_r;
        end else begin
            acc_l <= acc_l + mux_l;
            acc_r <= acc_r + mux_r;
        end
    end
end

endmodule
