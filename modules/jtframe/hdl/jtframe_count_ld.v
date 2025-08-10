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
    Date: 20-7-2025 */

module jtframe_count_ld #(
    parameter // keep order
            W=10,
            ONE_SHOT=0  // set to 1 to start counting when ld goes high
                        // and continue until tc is set
)(
    // keep port order
    input  rst, clk, cen,
           en, ld, // ld takes priority over _en_ and does not require _cen_
    input      [W-1:0] cnt0,
    output reg [W-1:0] cnt=0,
    output reg         tc       // tc=&cnt
);

reg  bsy;
wire [W-1:0] nx_cnt = ld ? cnt0 : cnt+1'd1;
wire count_up = (ONE_SHOT==0 || bsy) && en;

always @(posedge clk) begin
    if( rst ) begin
        cnt  <= 0;
        tc   <= 0;
        bsy  <= 0;
    end else if(cen) begin
        if( count_up | ld ) begin
            cnt <=  nx_cnt;
            tc  <= &nx_cnt;
            if(&nx_cnt ) bsy <= 0;
            if( ld     ) bsy <= 1;
        end
        if( !bsy && ONE_SHOT==1 ) tc <= 0;
    end
end

endmodule