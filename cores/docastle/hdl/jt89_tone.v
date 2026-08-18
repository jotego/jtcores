/*  This file is part of JT89.

    JT89 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT89 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT89.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: March, 8th 2017
    
    This work was originally based in the implementation found on the
    SMS core of MiST
    
    */

module jt89_tone(
    input               clk,
(* direct_enable = 1 *) input   clk_en,
    input               rst,
    input         [9:0] tone,
    input         [3:0] vol,
    output        [8:0] snd,
    output reg          out
);

parameter DEAF_TONE = 5; // The DAC will not react to tones this fast

reg [9:0] cnt;
reg last_out;

jt89_vol u_vol(
    .rst    ( rst     ),
    .clk    ( clk     ),
    .clk_en ( clk_en  ),
    .din    ( out     ),
    .vol    ( vol     ),
    .snd    ( snd     )
);

always @(posedge clk) 
    if( rst ) begin
        cnt <= 10'd0;
        out <= 1'b0;
    end else if( clk_en ) begin
        if( tone <= DEAF_TONE ) // This is used for sample playing
            out <= 1'b1;
        else begin
            if( cnt[9:0]==10'd1 ) begin 
                cnt[9:0] <= (tone==10'd0) ? 10'd1 : tone;
                out <= ~out;
            end
            else cnt <= cnt-10'b1;
        end
    end

endmodule
