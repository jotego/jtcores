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

    Author: Jose Tejada Gomez. https://patreon.com/jotego
    Version: 1.0
    Date: 22-3-2022 */

module jtngp_vtimer(
    input               clk,
    input               hint_en,
    input               vint_en,

    input               cen6,
    input               pxl_cen,
    input               pxl2_cen,
    output reg  [9:0]   hcnt,       // top 8 bits
    output reg  [8:0]   hdump,
    output reg  [7:0]   vdump, vrender,
    input       [7:0]   view_height, view_starty,
    output reg          LHBL,
    output reg          LVBL,
    output reg          HS,
    output reg          VS,

    output reg          hirq,
    output reg          virq
);

localparam HBSTART  = 9'd169,
           HS0      = 9'd170,
           HBEND    = 9'd9;       // 170 pixels in haux count (21*8 plus two dummy pixels during HS)

reg [7:0] virq_line;
reg [1:0] dummy;
reg [8:0] haux,hcmp=0;

initial begin
    hirq = 0;
    virq = 0;
end

always @* hdump=haux;

always @(posedge clk) begin
    if( cen6 ) hcnt <= hcnt-10'd1;
    if(pxl_cen) begin
        // hdump <= haux==hcmp ? -9'd16: hdump+9'd1;
        virq_line <= view_height+view_starty;
        if( haux!=HS0 || dummy==3 ) haux<= haux==HS0 ? 9'd0 : haux+1'd1;
        if( haux==HS0 ) begin
            hirq  <= 0;
            virq  <= 0;
            HS    <= dummy!=2'b11;
            dummy <= { dummy[0],1'b1 };
            if( dummy==0 ) begin
                vrender <= (vrender==198) ? 8'd0 : (vrender+8'd1);
                vdump   <=  vrender;
                virq    <=  vint_en && vdump==virq_line;
                hirq    <=  hint_en && (vdump<150 || vdump==198 );
                if( vdump==151 )
                    LVBL <= 0;
                else if( vdump==198 ) begin
                    LVBL <= 1;
                    hcmp <= hcmp+9'd1;
                end
                if( vdump==180 )
                    VS <= 1;
                else if( vdump==183 )
                    VS <= 0;
            end
        end
        if( haux==HBEND ) begin
            LHBL  <= 1;
            dummy <= 0;
        end
        if( haux==HBSTART ) begin
            hcnt  <= 511;
            LHBL  <= 0;
        end
    end
end

endmodule
