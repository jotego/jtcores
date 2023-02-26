/*  This file is part of JTNGP.
    JTNGP program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTNGP program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTNGP.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. https://patreon.com/jotego
    Version: 1.0
    Date: 22-3-2022 */

module jtngp_vtimer(
    input               clk,
    input         [1:0] video_cen,
    input               hint_en,
    input               vint_en,

    output reg          pxl_cen,
    output reg          pxl2_cen,
    output reg  [9:0]   hcnt,       // top 8 bits
    output reg  [8:0]   hdump,
    output reg  [7:0]   vdump,
    output reg  [7:0]   vrender,
    output reg          LHBL,
    output reg          LVBL,
    output reg          HS,
    output reg          VS,

    output reg          hirq,
    output reg          virq
);

reg [2:0] three=1;

initial begin
    hirq = 0;
    virq = 0;
end

always @(posedge clk) begin
    pxl_cen  <= video_cen[1] & three[2];
    pxl2_cen <= video_cen[1] & (three[2] | three[0]);
    if( video_cen[1] ) begin
        three <= { three[1:0], three[2] };
        if( hcnt==6 ) begin
            hirq <= 0;
            virq <= 0;
        end
        if( hcnt==(160*3-1) ) begin
            LHBL <= 0;
        end
        if( hcnt == 500 ) HS <= 1;
        if( hcnt==514 ) begin
            HS       <= 0;
            LHBL     <= 1;
            hdump    <= 0;
            three    <= 1;
            pxl_cen  <= 1;
            pxl2_cen <= 1;
            hcnt     <= 0;
            vrender  <= (vrender==198) ? 8'd0 : (vrender+8'd1);
            vdump    <= vrender;
            virq  <= vint_en && vdump==151;
            hirq  <= hint_en && (vdump<150 || vdump==198 );
            if( vdump==159 )
                LVBL <= 0;
            else if( vdump==198 )
                LVBL <= 1;
            if( vdump==180 )
                VS <= 1;
            else if( vdump==183 )
                VS <= 0;
        end else begin
            if( three[2] ) hdump <= hdump + 9'd1;
            hcnt  <= hcnt  +10'd1;
        end
    end
end

endmodule
