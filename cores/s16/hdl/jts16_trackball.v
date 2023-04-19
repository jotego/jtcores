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
    Date: 30-10-2021 */

module jts16_trackball(
    input             rst,
    input             clk,
    input             LHBL,

    input             right_en,

    input      [ 7:0] joystick1,
    input      [ 7:0] joystick2,
    input      [ 7:0] joystick3,
    input      [ 7:0] joystick4,
    input      [15:0] joyana1,
    input      [15:0] joyana1b, // used by Heavy Champ
    input      [15:0] joyana2,
    input      [15:0] joyana2b, // used by SDI
    input      [15:0] joyana3,
    input      [15:0] joyana4,

    output reg [11:0] trackball0,
    output reg [11:0] trackball1,
    output reg [11:0] trackball2,
    output reg [11:0] trackball3,
    output reg [11:0] trackball4,
    output reg [11:0] trackball5,
    output reg [11:0] trackball6,
    output reg [11:0] trackball7
);

reg         LHBLl;
reg  [ 5:0] hcnt;

wire [15:0] mainstick1 = right_en ? joyana1b : joyana1;
wire [15:0] mainstick2 = right_en ? joyana2b : joyana2;

function [11:0] extjoy( input [7:0] ja );
    extjoy = { {8{ja[7]}}, ja[6:3] };
endfunction


always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hcnt <= 0;
        trackball0 <= 12'h10a;
        trackball1 <= 12'h20b;
        trackball2 <= 12'h30c;
        trackball3 <= 12'h40d;
        trackball4 <= 12'h50e;
        trackball5 <= 12'h60f;
        trackball6 <= 12'h701;
        trackball7 <= 12'h802;
    end else begin
        LHBLl <= LHBL;
        if( !LHBL && LHBLl ) begin
            hcnt<=hcnt+6'd1;
            if( hcnt==0 ) begin
                trackball0 <= trackball0 - extjoy( mainstick1[ 7:0] ); // X
                trackball1 <= trackball1 + extjoy( mainstick1[15:8] ); // Y
                trackball2 <= trackball2 - extjoy( mainstick2[ 7:0] );
                trackball3 <= trackball3 + extjoy( mainstick2[15:8] );
                trackball4 <= trackball4 - extjoy( joyana3[ 7:0] );
                trackball5 <= trackball5 + extjoy( joyana3[15:8] );
                trackball6 <= trackball6 - extjoy( joyana4[ 7:0] );
                trackball7 <= trackball7 + extjoy( joyana4[15:8] );
            end
        end
    end
end

endmodule