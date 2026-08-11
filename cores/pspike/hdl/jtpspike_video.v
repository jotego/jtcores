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
    Date: 10-8-2026 */

// C7-01 GGA video timing. 7.159MHz pixel clock over a 456x256 grid,
// 352x240 visible

module jtpspike_video(
    input               rst,
    input               clk,
    input               pxl_cen,

    input               turbofrc, aerofgt,
    input      [31:0]   gfxbank,    // eight 4-bit banks
    input      [ 2:0]   charbank,
    input      [ 1:0]   objbank,
    input               flip,
    input      [ 8:0]   scry, scrx1, scry1,

    // tilemap VRAM
    output     [12:1]   scr_addr,
    input      [15:0]   scr_vram,
    output     [12:1]   scr1v_addr,
    input      [15:0]   scr1_vram,
    // raster RAM
    output     [11:1]   ras_addr,
    input      [15:0]   ras_dout,
    // sprite RAM. The second chip reads the upper half of its own copy
    output     [10:1]   objr_addr,
    input      [15:0]   objr_dout,
    output     [10:1]   objr1_addr,
    input      [15:0]   objr1_dout,
    // sprite tile lookup RAM
    output     [13:1]   objl_addr,
    input      [15:0]   objl_dout,
    output     [13:1]   objl1_addr,
    input      [15:0]   objl1_dout,
    // palette
    output     [11:1]   mix_addr,
    input      [15:0]   mix_pal,

    output     [19:2]   scr0_addr,
    output              scr0_cs,
    input      [31:0]   scr0_data,
    input               scr0_ok,
    output     [20:2]   scr1_addr,
    output              scr1_cs,
    input      [31:0]   scr1_data,
    input               scr1_ok,

    output     [21:2]   obj0_addr,
    output              obj0_cs,
    input      [31:0]   obj0_data,
    input               obj0_ok,
    output     [20:2]   obj1_addr,
    output              obj1_cs,
    input      [31:0]   obj1_data,
    input               obj1_ok,

    input      [ 3:0]   gfx_en,

    output              LHBL, LVBL, HS, VS,
    output     [ 4:0]   red, green, blue
);

// Taken from the GGA register table the game writes at boot (ROM 0x1202e).
// H registers count in units of 4 pixels, V registers in units of 2 lines,
// both biased by one unit:
//   00=57 -> 352 HB start   01=63 -> 400 HS start
//   02=69 -> 424 HS end     03=71 -> 456 H total
//   08=77 -> 240 VB start   09=79 -> 244 VS start
//   0a=7b -> 248 VS end     0b=7f -> 256 V total
localparam [8:0] V_START  = 9'd0,
                 VB_START = 9'd239,
                 VB_END   = 9'd255,
                 VS_START = 9'd244,
                 VS_END   = 9'd248,
                 HB_START = 9'd351,
                 HB_END   = 9'd455,
                 HS_START = 9'd400,
                 HS_END   = 9'd424,
                 HCNT_END = 9'd455;

// MAME's visible window starts at pixel 4 of the 456 count, and
// jtframe_tilemap outputs eight pixels behind its fetch. Both layers are fed
// an hdump running this much ahead so the picture lands at x=0 with no left
// hand black bar. Wrapped on the 456 grid so the count stays continuous
// through the end of the line and the pipeline primes correctly
// Tiles and sprites do not share the same pipeline depth, so each layer gets
// its own lead. Sprites sit 9 pixels right of the tilemap.
//
// Part of the lead is the visible window offset, and it is NOT the same for
// both games: pspikes is set_visarea(0*8+4,...) so its picture starts at x=4,
// turbofrc is set_visarea(0*8,...) and starts at x=0. The remaining 10 is the
// tilemap pipeline. Carrying the pspikes 4 over to turbofrc stacks with the
// per layer scroll bias and shifts the whole picture along the scanline
// Visible window start differs per game: pspikes x=4, turbofrc x=0,
// aerofgtb x=12 (set_visarea(0*8+12,...)). The other 10 is the tilemap pipeline
wire       two      = turbofrc | aerofgt;
wire [8:0] hoff_scr = aerofgt ? 9'd22 : turbofrc ? 9'd10 : 9'd14;
// MAME per layer bias: -11 / -7, and aerofgtb adds set_scrolldx(1,1) to both
wire [8:0] xb0      = aerofgt ? 9'd10 : 9'd11;
wire [8:0] xb1      = aerofgt ? 9'd6  : 9'd7;
wire [8:0] hoff_obj = hoff_scr - 9'd9;

wire [ 8:0] vdump, vrender, H, hdump_scr, hdump_obj;
wire [ 9:0] scr_pxl, scr1_pxl;
wire [10:0] obj_pxl, obj1_pxl;
wire [10:0] pxl;
wire [20:2] scr1_raw, scr0_raw;
wire [21:2] obj1_raw;
wire        s0_op, s1_op, o0_op, o1_op;

assign scr1_addr = scr1_raw;
assign scr0_addr = scr0_raw[19:2];
assign obj1_addr = obj1_raw[20:2];
// the second chip walks the upper half of the sprite RAM
assign objr1_addr[10] = 1'b1;
assign objr_addr[10]  = 1'b0;
assign hdump_scr = H >= (HCNT_END-hoff_scr+9'd1) ? H+hoff_scr-(HCNT_END+9'd1) : H+hoff_scr;
assign hdump_obj = H >= (HCNT_END-hoff_obj+9'd1) ? H+hoff_obj-(HCNT_END+9'd1) : H+hoff_obj;

// Sprites are transparent on pen 15 and the line buffer reads back 15 where
// nothing was drawn. Tile layer 1 is transparent on pen 15 too
assign s0_op = 1'b1;                    // layer 0 is the opaque background
assign s1_op = ~&scr1_pxl[3:0];
assign o0_op = ~&obj_pxl[3:0];
assign o1_op = ~&obj1_pxl[3:0];

// pspikes  palette 2048: tiles 0-1023, sprites 1024-2047
// turbofrc palette 1024 in four fixed blocks of 256:
//          layer 0, layer 1, sprites 0, sprites 1
// Order back to front on turbofrc is layer 0, sprites with pri==0, layer 1,
// sprites with pri==1 - layer 1 masks the low priority sprites
// turbofrc sprite pixel: pal[6:0] is {pri, objbank, colour}, and only the
// four colour bits index its 256 entry block
wire [10:0] o0_idx = { 3'b010, obj_pxl [7:4], obj_pxl [3:0] };
wire [10:0] o1_idx = { 3'b011, obj1_pxl[7:4], obj1_pxl[3:0] };

assign pxl = !two ? ( o0_op ? { 1'b1, obj_pxl[9:0] } : { 1'b0, scr_pxl } ) :
             ( o1_op & obj1_pxl[10] ) ? o1_idx :
             ( o0_op & obj_pxl [10] ) ? o0_idx :
               s1_op                  ? { 1'b0, 2'b01, scr1_pxl[7:0] } :
               o1_op                  ? o1_idx :
               o0_op                  ? o0_idx :
                                        { 1'b0, 2'b00, scr_pxl[7:0] };

jtframe_vtimer #(
    .V_START    ( V_START   ),
    .VB_START   ( VB_START  ),
    .VB_END     ( VB_END    ),
    .VS_START   ( VS_START  ),
    .VS_END     ( VS_END    ),
    .HB_START   ( HB_START  ),
    .HB_END     ( HB_END    ),
    .HS_START   ( HS_START  ),
    .HS_END     ( HS_END    ),
    .HCNT_END   ( HCNT_END  )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   (           ),
    .H          ( H         ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

jtpspike_scr u_scr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .flip       ( flip      ),
    .hdump      ( hdump_scr ),
    .vdump      ( vdump     ),
    .blankn     ( gfx_en[0] ),
    .two        ( two       ),
    .xbias      ( xb0       ),
    .layer      ( 1'b0      ),
    .gfxbank    ( gfxbank   ),
    .charbank   ( charbank  ),
    .scrx       ( 9'd0      ),   // layer 0 takes its scroll from the raster RAM
    .scry       ( scry      ),
    .scr_addr   ( scr_addr  ),
    .scr_vram   ( scr_vram  ),
    .ras_addr   ( ras_addr  ),
    .ras_dout   ( ras_dout  ),
    .rom_addr   ( scr0_raw  ),
    .rom_cs     ( scr0_cs   ),
    .rom_data   ( scr0_data ),
    .rom_ok     ( scr0_ok   ),
    .pxl        ( scr_pxl   )
);

// Second tile layer, turbofrc onwards. Idle on pspikes
jtpspike_scr u_scr1(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .flip       ( flip      ),
    .hdump      ( hdump_scr ),
    .vdump      ( vdump     ),
    .blankn     ( gfx_en[1] & two ),
    .two        ( two       ),
    .xbias      ( xb1       ),
    .layer      ( 1'b1      ),
    .gfxbank    ( gfxbank   ),
    .charbank   ( 3'd0      ),
    .scrx       ( scrx1     ),
    .scry       ( scry1     ),
    .scr_addr   ( scr1v_addr),
    .scr_vram   ( scr1_vram ),
    .ras_addr   (           ),
    .ras_dout   ( 16'd0     ),
    .rom_addr   ( scr1_raw  ),
    .rom_cs     ( scr1_cs   ),
    .rom_data   ( scr1_data ),
    .rom_ok     ( scr1_ok   ),
    .pxl        ( scr1_pxl  )
);

jtpspike_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .flip       ( flip      ),
    .hdump      ( hdump_obj ),
    .vrender    ( vrender   ),
    .en         ( 1'b1      ),
    .objbank    ( objbank   ),
    .objr_addr  ( objr_addr[9:1] ),
    .objr_dout  ( objr_dout ),
    .objl_addr  ( objl_addr ),
    .objl_dout  ( objl_dout ),
    .rom_addr   ( obj0_addr ),
    .rom_cs     ( obj0_cs   ),
    .rom_data   ( obj0_data ),
    .rom_ok     ( obj0_ok   ),
    .pxl        ( obj_pxl   )
);

// Second sprite chip. It walks the upper half of the sprite RAM, so its copy
// is addressed with the top bit forced high
jtpspike_obj u_obj1(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .en         ( two       ),
    .flip       ( flip      ),
    .hdump      ( hdump_obj ),
    .vrender    ( vrender   ),
    .objbank    ( objbank   ),
    .objr_addr  ( objr1_addr[9:1] ),
    .objr_dout  ( objr1_dout),
    .objl_addr  ( objl1_addr),
    .objl_dout  ( objl1_dout),
    .rom_addr   ( obj1_raw  ),
    .rom_cs     ( obj1_cs   ),
    .rom_data   ( obj1_data ),
    .rom_ok     ( obj1_ok   ),
    .pxl        ( obj1_pxl  )
);

jtpspike_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .pxl        ( pxl       ),
    .mix_addr   ( mix_addr  ),
    .mix_pal    ( mix_pal   ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

endmodule
