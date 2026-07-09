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

    Block Out back-framebuffer video fetch (clk 48 MHz / SDRAM domain).

    The 256 KB framebuffer (SDRAM bank 2) holds two byte-per-pixel 512x256
    planes: front @ byte 0 (word 0x00000-0x0ffff), back @ byte 0x20000 (word
    0x10000-0x1ffff). Word address = {plane, y[7:0], wcol[7:0]}; each 16-bit
    word packs 2 pixels — even x (68k big-endian) in the high byte, odd x low.
    Composite per MAME videoram_w:  pen = front ? {0,front} : {1,back}  (9-bit).

    A double line buffer (2 pixels/entry) is filled a line ahead; scanout reads
    the displayed half. CPU R/W to the bitmap is handled separately (straight to
    the fbram SDRAM port in the game top) so this module stays purely clk48.
*/

module jtblockout_fb(
    input               rst,
    input               clk,
    input               pxl_cen,

    input        [ 8:0] hdump,      // 0..511 pixel column
    input        [ 8:0] vrender,    // line to fetch (1 ahead of display)
    input               HS,

    // SDRAM bank 2 video-read port
    output reg   [17:1] fbrd_addr,
    output reg          fbrd_cs,
    input        [15:0] fbrd_data,
    input               fbrd_ok,

    output reg   [ 8:0] fb_pxl       // 9-bit pen at hdump (0..511)
);

// ── line fetch FSM ──────────────────────────────────────────────────────────
// Each SDRAM read fully handshakes: assert cs+addr, wait ok, capture, drop cs
// (forces ok low before the next request). Per column: front word, back word,
// then compose+store 2 pixels.
localparam [2:0] IDLE=0, F_REQ=1, F_WAIT=2, B_REQ=3, B_WAIT=4, STORE=5;
reg  [ 2:0] st;
reg         disp, HSl;
reg  [ 7:0] wcol, fy;
reg  [15:0] front_lat, back_lat;
reg  [17:0] lb_din;                  // {pen_odd, pen_even}
reg  [ 8:0] lb_wa;
reg         lb_we;
wire [17:0] lb_q;

// composite one plane-pair -> 9-bit pen
function [8:0] compose( input [7:0] f, input [7:0] b );
    compose = f!=8'd0 ? {1'b0,f} : {1'b1,b};
endfunction

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st<=IDLE; disp<=0; HSl<=0; fbrd_cs<=0; wcol<=0; lb_we<=0;
        fbrd_addr<=0; fy<=0; front_lat<=0; back_lat<=0;
    end else begin
        HSl   <= HS;
        lb_we <= 0;
        if( HS && !HSl ) begin              // new line: swap buffers, start fetch
            disp <= ~disp;
            fy   <= vrender[7:0] + 8'd10;    // shift image up 10px (MAME visarea V=10)
            wcol <= 0;
            st   <= F_REQ;
        end else case( st )
            F_REQ:  begin fbrd_addr<={1'b0,fy,wcol}; fbrd_cs<=1; st<=F_WAIT; end
            F_WAIT: if( fbrd_ok ) begin front_lat<=fbrd_data; fbrd_cs<=0; st<=B_REQ; end
            B_REQ:  begin fbrd_addr<={1'b1,fy,wcol}; fbrd_cs<=1; st<=B_WAIT; end
            B_WAIT: if( fbrd_ok ) begin back_lat<=fbrd_data;  fbrd_cs<=0; st<=STORE; end
            STORE:  begin
                lb_din <= { compose(front_lat[7:0],  back_lat[7:0] ),    // odd  x
                            compose(front_lat[15:8], back_lat[15:8]) };  // even x
                lb_wa  <= { ~disp, wcol };
                lb_we  <= 1;
                if( wcol==8'd255 ) st<=IDLE;
                else begin wcol<=wcol+8'd1; st<=F_REQ; end
            end
            default: st<=IDLE;
        endcase
    end
end

// horizontal read: +2 aligns the displayed image with MAME (measured by
// cross-correlation). The read runs 2 px ahead so the fb_pxl->rgb pipeline is
// primed by the first visible pixel.
wire [8:0] hrd = hdump + 9'd2;

// double line buffer: 256 cols x 2 buffers, 2 pixels/entry
jtframe_dual_ram #(.DW(18), .AW(9)) u_lbuf(
    .clk0   ( clk               ),
    .data0  ( lb_din            ),
    .addr0  ( lb_wa             ),
    .we0    ( lb_we             ),
    .q0     (                   ),
    .clk1   ( clk               ),
    .data1  ( 18'd0             ),
    .addr1  ( { disp, hrd[8:1] } ),
    .we1    ( 1'b0              ),
    .q1     ( lb_q              )
);

always @(posedge clk) if( pxl_cen )
    fb_pxl <= hrd[0] ? lb_q[17:9] : lb_q[8:0];

endmodule
