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
    Date: 28-4-2024 */

// Model of SEGA's 315-5242 DAC
// based on RE work in
// https://github.com/furrtek/SiliconRE
// DAC values derived from electrical network analysis

module jtshanon_coldac(
    input            clk,
    input            pxl_cen,
    input      [4:0] rin, gin, bin,
    input            en,
    input            sh,
    input            hilo,
    output reg [5:0] rout, gout, bout
);

reg [5:0] lvl;
reg [4:0] act;
reg [3:0] cnt;

always @(posedge clk) begin
    cnt <= cnt<<1;
    if(pxl_cen) begin
        cnt <= 1;
        act <= rin;
    end
    if( cnt[0] )  act        <=  gin;
    if( cnt[1] ) {act, rout} <= {bin, lvl};
    if( cnt[2] )       gout  <=       lvl;
    if( cnt[3] )       bout  <=       lvl;
    if( !en ) {rout,gout,bout} <= 0;
    casez( {act,sh,hilo})
        // normal tones
        {5'd00, 2'b0?}: lvl <= 0;
        {5'd01, 2'b0?}: lvl <= 2;
        {5'd02, 2'b0?}: lvl <= 4;
        {5'd03, 2'b0?}: lvl <= 5;
        {5'd04, 2'b0?}: lvl <= 7;
        {5'd05, 2'b0?}: lvl <= 9;
        {5'd06, 2'b0?}: lvl <= 10;
        {5'd07, 2'b0?}: lvl <= 12;
        {5'd08, 2'b0?}: lvl <= 15;
        {5'd09, 2'b0?}: lvl <= 16;
        {5'd10, 2'b0?}: lvl <= 18;
        {5'd11, 2'b0?}: lvl <= 20;
        {5'd12, 2'b0?}: lvl <= 22;
        {5'd13, 2'b0?}: lvl <= 24;
        {5'd14, 2'b0?}: lvl <= 25;
        {5'd15, 2'b0?}: lvl <= 27;
        {5'd16, 2'b0?}: lvl <= 31;
        {5'd17, 2'b0?}: lvl <= 33;
        {5'd18, 2'b0?}: lvl <= 35;
        {5'd19, 2'b0?}: lvl <= 36;
        {5'd20, 2'b0?}: lvl <= 38;
        {5'd21, 2'b0?}: lvl <= 40;
        {5'd22, 2'b0?}: lvl <= 42;
        {5'd23, 2'b0?}: lvl <= 43;
        {5'd24, 2'b0?}: lvl <= 46;
        {5'd25, 2'b0?}: lvl <= 47;
        {5'd26, 2'b0?}: lvl <= 49;
        {5'd27, 2'b0?}: lvl <= 51;
        {5'd28, 2'b0?}: lvl <= 53;
        {5'd29, 2'b0?}: lvl <= 55;
        {5'd30, 2'b0?}: lvl <= 56;
        {5'd31, 2'b0?}: lvl <= 58;
        // dimmed
        {5'd00, 2'b10}: lvl <= 0;
        {5'd01, 2'b10}: lvl <= 0;
        {5'd02, 2'b10}: lvl <= 1;
        {5'd03, 2'b10}: lvl <= 1;
        {5'd04, 2'b10}: lvl <= 1;
        {5'd05, 2'b10}: lvl <= 2; // values above this point were rounded up
        {5'd06, 2'b10}: lvl <= 2; // to avoid too many zero entries
        {5'd07, 2'b10}: lvl <= 3;
        {5'd08, 2'b10}: lvl <= 4;
        {5'd09, 2'b10}: lvl <= 5;
        {5'd10, 2'b10}: lvl <= 7;
        {5'd11, 2'b10}: lvl <= 8;
        {5'd12, 2'b10}: lvl <= 9;
        {5'd13, 2'b10}: lvl <= 11;
        {5'd14, 2'b10}: lvl <= 12;
        {5'd15, 2'b10}: lvl <= 14;
        {5'd16, 2'b10}: lvl <= 17;
        {5'd17, 2'b10}: lvl <= 18;
        {5'd18, 2'b10}: lvl <= 20;
        {5'd19, 2'b10}: lvl <= 21;
        {5'd20, 2'b10}: lvl <= 23;
        {5'd21, 2'b10}: lvl <= 24;
        {5'd22, 2'b10}: lvl <= 25;
        {5'd23, 2'b10}: lvl <= 27;
        {5'd24, 2'b10}: lvl <= 29;
        {5'd25, 2'b10}: lvl <= 30;
        {5'd26, 2'b10}: lvl <= 32;
        {5'd27, 2'b10}: lvl <= 33;
        {5'd28, 2'b10}: lvl <= 34;
        {5'd29, 2'b10}: lvl <= 36;
        {5'd30, 2'b10}: lvl <= 37;
        {5'd31, 2'b10}: lvl <= 38;
        // bright
        {5'd00, 2'b11}: lvl <= 17;
        {5'd01, 2'b11}: lvl <= 18;
        {5'd02, 2'b11}: lvl <= 20;
        {5'd03, 2'b11}: lvl <= 21;
        {5'd04, 2'b11}: lvl <= 23;
        {5'd05, 2'b11}: lvl <= 24;
        {5'd06, 2'b11}: lvl <= 25;
        {5'd07, 2'b11}: lvl <= 27;
        {5'd08, 2'b11}: lvl <= 29;
        {5'd09, 2'b11}: lvl <= 30;
        {5'd10, 2'b11}: lvl <= 32;
        {5'd11, 2'b11}: lvl <= 33;
        {5'd12, 2'b11}: lvl <= 34;
        {5'd13, 2'b11}: lvl <= 36;
        {5'd14, 2'b11}: lvl <= 37;
        {5'd15, 2'b11}: lvl <= 38;
        {5'd16, 2'b11}: lvl <= 42;
        {5'd17, 2'b11}: lvl <= 43;
        {5'd18, 2'b11}: lvl <= 45;
        {5'd19, 2'b11}: lvl <= 46;
        {5'd20, 2'b11}: lvl <= 47;
        {5'd21, 2'b11}: lvl <= 49;
        {5'd22, 2'b11}: lvl <= 50;
        {5'd23, 2'b11}: lvl <= 51;
        {5'd24, 2'b11}: lvl <= 54;
        {5'd25, 2'b11}: lvl <= 55;
        {5'd26, 2'b11}: lvl <= 56;
        {5'd27, 2'b11}: lvl <= 58;
        {5'd28, 2'b11}: lvl <= 59;
        {5'd29, 2'b11}: lvl <= 60;
        {5'd30, 2'b11}: lvl <= 62;
        {5'd31, 2'b11}: lvl <= 63;
    endcase
end

endmodule