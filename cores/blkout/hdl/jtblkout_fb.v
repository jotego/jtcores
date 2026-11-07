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
    Date: 31-7-2026
*/

module jtblkout_fb(
    input               rst,
    input               clk,
    input               pxl_cen,

    input        [ 8:0] hdump,
    input        [ 8:0] vrender,    // line to fetch (1 ahead of display)
    input               HS,

    output reg   [17:1] fbrd_addr,
    output reg          fbrd_cs,
    input        [15:0] fbrd_data,
    input               fbrd_ok,

    output reg   [ 8:0] fb_pxl       // 9-bit pen at hdump
);

localparam [2:0] IDLE=0, F_REQ=1, F_WAIT=2, B_REQ=3, B_WAIT=4, STORE=5;
localparam [0:0] FRONT=1'b0, BACK=1'b1;

reg  [ 2:0] st;
reg         HSl;
reg  [ 7:0] wcol, fy;
reg  [15:0] front_lat, back_lat;
reg  [17:0] lb_din;                  // {pen_odd, pen_even}
reg  [ 7:0] lb_wa;
reg         lb_we;
wire [17:0] lb_q;

// select front or back layers
function [8:0] compose( input [7:0] f, input [7:0] b );
    compose = f!=8'd0 ? {1'b0,f} : {1'b1,b};
endfunction

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st<=IDLE; HSl<=0; fbrd_cs<=0; wcol<=0; lb_we<=0;
        fbrd_addr<=0; fy<=0; front_lat<=0; back_lat<=0;
    end else begin
        HSl   <= HS;
        lb_we <= 0;
        if( HS && !HSl ) begin              // new line: start fetch (linebuf swaps)
            fy   <= vrender[7:0] + 8'd10;    // shift image up 10px (MAME visarea V=10)
            wcol <= 0;
            st   <= F_REQ;
        end else case( st )
            F_REQ:  begin fbrd_addr<={FRONT,fy,wcol}; fbrd_cs<=1; st<=F_WAIT; end
            F_WAIT: if( fbrd_ok ) begin front_lat<=fbrd_data; fbrd_cs<=0; st<=B_REQ; end
            B_REQ:  begin fbrd_addr<={BACK,fy,wcol}; fbrd_cs<=1; st<=B_WAIT; end
            B_WAIT: if( fbrd_ok ) begin back_lat<=fbrd_data;  fbrd_cs<=0; st<=STORE; end
            STORE:  begin
                lb_din <= { compose(front_lat[7:0],  back_lat[7:0] ),    // odd  x
                            compose(front_lat[15:8], back_lat[15:8]) };  // even x
                lb_wa  <= wcol;
                lb_we  <= 1;
                if( wcol==8'd255 ) st<=IDLE;
                else begin wcol<=wcol+8'd1; st<=F_REQ; end
            end
            default: st<=IDLE;
        endcase
    end
end

// read runs 2px ahead so the fb_pxl->rgb pipeline is primed at the first pixel
wire [8:0] hrd = hdump + 9'd2;

jtframe_linebuf #(.DW(18), .AW(8)) u_lbuf(
    .clk     ( clk       ),
    .LHBL    ( ~HS       ),
    .wr_addr ( lb_wa     ),
    .wr_data ( lb_din    ),
    .we      ( lb_we     ),
    .rd_addr ( hrd[8:1]  ),
    .rd_data ( lb_q      ),
    .rd_gated(           )
);

always @(posedge clk) if( pxl_cen ) begin
    fb_pxl <= hrd[0] ? lb_q[17:9] : lb_q[8:0];
end

endmodule
