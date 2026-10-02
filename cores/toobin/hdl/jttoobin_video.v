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

    Author: Andrea Bogazzi. andreabogazzi79@gmail.com
    Version: 1.0
    Date: 27-06-2026 */

// Toobin' video — bring-up stage 1: PLAYFIELD only (the scroller).
//   Playfield = 128x64 8x8 4bpp scrolling tilemap (jtframe_scroll). The real chip is
//   the SOS-1 serializer (PFRD16 -> PFPIX4); here jtframe_scroll does the fetch+shift,
//   driven by the schematic's tile format. Alpha + motion objects + GPC priority land next.
//
// Tile entry (32-bit, MAME get_playfield_tile_info): code=[13:0], flipYX=[15:14],
//   color=[19:16], category=[21:20]. Stored as two 16-bit words in the pf BRAM.
// Tile gfx (pflayout, RGN_FRAC(1,2)): planes 2,3 in the first ROM half, 0,1 in the
//   second (+0x20000 words). Plane de-interleave is a FIRST GUESS — graded vs MAME.
module jttoobin_video #( parameter COLORW=5 )(
    input               rst,
    input               clk,
    input               pxl_cen,
    input        [ 8:0] hdump,
    input        [ 8:0] vdump,
    input               hs,
    input               LHBL,
    input               LVBL,
    input               flip,

    // scroll registers from the CPU (>>6 = pixel scroll)
    input        [15:0] xscroll,
    input        [15:0] yscroll,

    // playfield tilemap RAM (dual-port read side; 32-bit tile entry)
    output       [12:0] pf_addr,     // tile index (128x64 = 8192 tiles)
    input        [31:0] pf_dout,

    // playfield tile gfx ROM (SDRAM)
    output       [18:1] tile_addr,
    input        [15:0] tile_data,
    output              tile_cs,
    input               tile_ok,

    // palette RAM (dual-port read side)
    output       [ 9:0] pal_addr,
    input        [15:0] pal_data,

    output [COLORW-1:0] red,
    output [COLORW-1:0] green,
    output [COLORW-1:0] blue
);

wire [13:0] code;
wire [ 3:0] color;
wire        hflip, vflip;
wire [ 7:0] pf_pxl;       // {color[3:0], pix[3:0]}
wire        blankn = LHBL & LVBL;

// scroll: registers are <<6 of the pixel value
wire [ 9:0] scrx = xscroll[15:6];   // 0..1023 (map is 1024 wide)
wire [ 8:0] scry = yscroll[14:6];   // 0..511

// ---- tile entry decode (32-bit) ----
assign code  = pf_dout[13:0];
assign hflip = pf_dout[14];
assign vflip = pf_dout[15];
assign color = pf_dout[19:16];

// ---- tile gfx fetch: jtframe_scroll asks rom_addr={code,V,Hhalf}; build the SDRAM
// address + de-interleave the two FRAC halves into {p3,p2,p1,p0}. Read both halves. ----
wire [16:0] scr_romaddr;             // {code[13:0], v[2:0]} for an 8x8 4bpp tile
reg  [15:0] tlo, thi;
wire [31:0] scr_romdata;

// SDRAM: low half (planes 2,3) at scr_romaddr; high half (planes 0,1) at +0x20000 words.
// data_width 16 -> read both halves into a 32-bit word for jtframe_scroll. (one read each;
// hardware reads two SOS-1 ROM halves in parallel.)
assign tile_addr = scr_romaddr[16] ? {2'b10, scr_romaddr[15:1]}   // high half
                                   : {2'b00, scr_romaddr[15:1]};  // low half
assign tile_cs   = blankn;
always @(posedge clk) if(pxl_cen) begin
    tlo <= tile_data;  // (placeholder pipeline — refined when 2-read fetch lands)
end
// FIRST-GUESS plane de-interleave (each 16b word = 2 planes, 4-bit nibble interleave)
wire [7:0] p2 = {tile_data[11:8], tile_data[3:0]};
wire [7:0] p3 = {tile_data[15:12],tile_data[7:4]};
wire [7:0] p0 = {tlo[11:8], tlo[3:0]};
wire [7:0] p1 = {tlo[15:12],tlo[7:4]};
assign scr_romdata = { p3, p2, p1, p0 };

jtframe_scroll #(
    .SIZE  ( 8        ),
    .VA    ( 13       ),   // 8192 tiles
    .CW    ( 14       ),   // code 0x3fff
    .PW    ( 8        ),   // {color[3:0], pix[3:0]}
    .MAP_HW( 10       ),   // 128 tiles * 8 = 1024 px
    .MAP_VW( 9        ),   // 64 tiles * 8 = 512 px
    .HJUMP ( 0        )
) u_pf(
    .rst       ( rst         ),
    .clk       ( clk         ),
    .pxl_cen   ( pxl_cen     ),
    .hs        ( hs          ),
    .vdump     ( vdump       ),
    .hdump     ( hdump       ),
    .blankn    ( blankn      ),
    .flip      ( flip        ),
    .scrx      ( scrx        ),
    .scry      ( scry        ),
    .vram_addr ( pf_addr     ),
    .code      ( code        ),
    .pal       ( color       ),
    .hflip     ( hflip       ),
    .vflip     ( vflip       ),
    .rom_addr  ( scr_romaddr ),
    .rom_data  ( scr_romdata ),
    .rom_cs    (             ),
    .rom_ok    ( tile_ok     ),
    .pxl       ( pf_pxl      )
);

// ---- palette: pen = playfield base(0) + {color,pix}; xRGB-555 (R=[14:10],G=[9:5],B=[4:0]) ----
assign pal_addr = { 2'b00, pf_pxl };   // playfield colorbase 0
reg [COLORW-1:0] r,g,b;
always @(posedge clk) if(pxl_cen) begin
    r <= pal_data[14:10];
    g <= pal_data[ 9: 5];
    b <= pal_data[ 4: 0];
end
assign {red,green,blue} = (LHBL&LVBL) ? {r,g,b} : {3*COLORW{1'b0}};

endmodule
