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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 9-8-2026 */

// Tricky Doc sprite table scan.
// Entries are 4 bytes long but the table starts at offset 3, so object n
// occupies bytes 4n+3 (y), 4n+4 (code), 4n+5 (x) and 4n+6 (attributes).
// 255 objects are scanned, matching the MAME loop bounds.
//
//  attributes: 7:4 colour, 3 vflip, 2 hflip, 1 x sign mode, 0 code MSB

module jttrcdoc_objscan(
    input             clk,
    input             hs,
    input             blankn,
    input      [ 8:0] vrender,

    output reg [ 8:0] code,
    output reg [ 8:0] hpos,
    output reg [ 3:0] ysub,
    output reg [ 3:0] pal,
    output reg        hflip, vflip,

    output     [ 9:0] ram_addr,
    input      [ 7:0] ram_dout,

    input             dr_busy,
    output            dr_draw
);

wire [9:0] raw_addr;
wire [8:0] vlatch;
wire [7:0] objcnt;
wire [1:0] st;
wire       cen, draw_step;

reg  [7:0] ypos, code_lsb, xpos;
reg  [9:0] ydiff;      // needs the sign bit: 236-ypos can be negative
reg  [8:0] sxm2, nx_hpos;
reg        inzone, xskip;

assign draw_step = st==3;
assign objcnt    = raw_addr[9:2];
assign ram_addr  = raw_addr + 10'd3;

always @* begin
    // MAME: sy = 236 - ypos, then the sprite spans 16 lines downwards.
    // Sprites above the top of the screen give a negative sy, so the
    // subtraction must not wrap
    ydiff = { 2'b0, vlatch[7:0] } + { 2'b0, ypos } - 10'd236;
    // MAME: sx = xpos - 2. Attribute bit 1 turns the position signed,
    // otherwise anything below 0x40 is off screen to the right
    sxm2  = { 1'b0, xpos } - 9'd2;
    xskip = ram_dout[1] ? 1'b0 : (sxm2[8] || sxm2[7:0] < 8'h40);
    nx_hpos = (ram_dout[1] && !sxm2[8] && sxm2[7:0] > 8'hc0) ? sxm2 - 9'd256 : sxm2;
    inzone = ydiff[9:4]==0 && !xskip && objcnt!=8'hff;
end

always @(posedge clk) if(cen) begin
    case( st )
        0: ypos     <= ram_dout;
        1: code_lsb <= ram_dout;
        2: xpos     <= ram_dout;
        3: begin
            code  <= { ram_dout[0], code_lsb };
            pal   <= ram_dout[7:4];
            hflip <= ram_dout[2];
            vflip <= ram_dout[3];
            hpos  <= nx_hpos;
            ysub  <= ydiff[3:0];
        end
    endcase
end

jtframe_objscan #(.OBJW(8),.STW(2),.HREPW(1),.HOLD_WHILE_DRBUSY(1))
u_scan(
    .clk        ( clk       ),
    .cen        ( cen       ),
    .hs         ( hs        ),
    .blankn     ( blankn    ),
    .vrender    ( vrender   ),
    .vlatch     ( vlatch    ),

    .draw_step  ( draw_step ),
    .skip       ( 1'b0      ),
    .inzone     ( inzone    ),

    .hsize      ( 1'b0      ),
    .hsub       (           ),
    .haddr      (           ),
    .hflip      ( hflip     ),
    .hcnt_nx    (           ),

    .dr_busy    ( dr_busy   ),
    .dr_draw    ( dr_draw   ),

    .addr       ( raw_addr  ),
    .step       ( st        )
);

endmodule
