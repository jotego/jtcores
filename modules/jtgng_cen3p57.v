/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-10-2019 */

// Generates a 3.57 MHz clock enable signal for a 48MHz clock
// Result: 105/1408 = 3,579,545.5 MHz, off by 0.5Hz (0.14ppm) :-)

module jtgng_cen3p57(
    input      clk,       // 48 MHz
    output reg cen_3p57,
    output reg cen_1p78
);

wire [10:0] step=11'd105;
wire [10:0] lim =11'd1408;
wire [10:0] absmax = lim+step;

reg  [10:0] cencnt=11'd0;
reg  [10:0] next;
reg  [10:0] next2;

always @(*) begin
    next  = cencnt+11'd105;
    next2 = next-lim;
end

reg alt=1'b0;

always @(negedge clk) begin
    cen_3p57 <= 1'b0;
    cen_1p78 <= 1'b0;
    if( cencnt >= absmax ) begin
        // something went wrong: restart
        cencnt <= 11'd0;
        alt    <= 1'b0;
    end else
    if( next >= lim ) begin
        cencnt <= next2;
        cen_3p57 <= 1'b1;
        alt    <= ~alt;
        if( alt ) cen_1p78 <= 1'b1;
    end else begin
        cencnt <= next;
    end
end

endmodule // jtgng_cen