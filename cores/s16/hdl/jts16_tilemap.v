/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 7-3-2021 */

// Implements 315-5197       -- System 16B and Out Run
// Implements 315-5049 (x2)  -- System 16A

// The tile map generator (TMG) works with two external 16-bit memories,
// a 64kB one is used for the scroll layers, and a 4kB one is used for
// the char layer. These RAM chips are external to the 315-5197
// but the control signals are inside the TMG.
// In this implementation, the select signal between char and scroll RAM
// is the main CPU module because they are located in different devices:
// the char RAM is made of BRAM, and the scroll RAM is mapped to the SDRAM

module jts16_tilemap(
    input              rst,
    input              clk,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              pxl_cen,   // pixel clock enable

    // CPU interface
    input              dip_pause,
    input              char_cs,
    input              pal_cs,
    input      [12:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dswn,

    output     [15:0]  char_dout,
    output             vint,    

    // Other configuration
    input              flip,
    inout              ext_flip,
    input              colscr_en,
    input              rowscr_en,
    input              alt_en, // This is controlled by pin 77, named K8 in sch.
                               // pin 77 was set with a jumper on the ROM board
                               // That pin corresponds to ~alt_en in Super Hang On sch.

    // SDRAM interface
    input              char_ok,
    output     [13:2]  char_addr, // 9 addr + 3 vertical + 2 horizontal = 14 bits
    input      [31:0]  char_data,

    input              map1_ok,
    output     [15:1]  map1_addr, // 3 pages + 11 addr = 14 (32 kB)
    input      [15:0]  map1_data,

    input              scr1_ok,
    output     [17:2]  scr1_addr, // 1 bank + 12 addr + 3 vertical = 15 bits
    input      [31:0]  scr1_data,

    input              map2_ok,
    output     [15:1]  map2_addr, // 3 pages + 11 addr = 14 (32 kB)
    input      [15:0]  map2_data,

    input              scr2_ok,
    output     [17:2]  scr2_addr, // 1 bank + 12 addr + 3 vertical = 15 bits
    input      [31:0]  scr2_data,    

    // Video signal
    output             HS,
    output             VS,
    output             preLHBL,
    output             preLVBL,
    output             hstart,    
    output             flipx,
    output      [ 8:0] hdump,
    output      [ 8:0] vdump,
    output      [ 8:0] vrender,

    // Layer mixing
    input       [11:0] obj_pxl,
    output      [10:0] pal_addr,
    output             shadow,
    // These are output pins in the original chip
    // but their function is unknown
    // they seem to toggle every 8 pixels
    // sa and sb don't toggle if only characters (the fix layer) is used
    output             fix,     // CHAR selected (?)
    output             sa,      // SCR1 selected (?)
    output             sb,      // SCR2 selected (?)
    // Set top priority
    input              set_fix,

    // Debug
    input       [ 3:0] gfx_en,
    input       [ 7:0] debug_bus,
    input       [ 7:0] st_addr,
    output      [ 7:0] st_dout,
    output             scr_bad
);

parameter MODEL = 1;
// Frame rate and horizontal frequency as the original
// "The sprite X position defines the starting location of the sprite. The
//  leftmost pixel of the screen is $00B6, and the rightmost is $1F5."
parameter [8:0] HB_END = 9'h0bf;

localparam [9:0] SCR2_DLY= MODEL ? 10'd9 : 10'd17;
localparam [9:0] SCR1_DLY= SCR2_DLY;

assign flipx    = flip;
assign ext_flip = flip;

wire [ 6:0] char_pxl;
wire [10:0] scr1_pxl, scr2_pxl;

// Scroll
wire [ 9:0] rowscr1, rowscr2;
wire [ 8:0] colscr1, colscr2;
wire        scr_start;
wire        col_busy1, col_busy2;
wire        scr1_bad, scr2_bad;

wire        rowscr1_en, rowscr2_en,
            colscr1_en, colscr2_en,
            altscr1_en, altscr2_en;
wire [ 8:0] scr1_hscan, scr2_hscan;

// MMR
wire [15:0] scr1_pages,      scr2_pages,
            scr1_hpos,       scr1_vpos,
            scr2_hpos,       scr2_vpos;


assign vint = vdump==223 && dip_pause;
assign scr_bad = scr1_bad | scr2_bad;

generate
    if( MODEL==0 ) begin
        assign rowscr1_en = rowscr_en;
        assign rowscr2_en = rowscr_en;
        assign colscr1_en = colscr_en;
        assign colscr2_en = colscr_en;
    end
endgenerate

jtframe_vtimer #(
    .HB_START  ( 9'h1ff ),
    .HB_END    ( HB_END ),
    .HCNT_START( 9'h70  ), // it should be 'h50
    .HCNT_END  ( 9'h1FF ),
    .VB_START  ( 9'h0DF ),
    .VB_END    ( 9'h105 ),
    .VCNT_END  ( 9'h105 ), // 262 lines
    //.VS_START ( 9'h0   ),
    .VS_START ( 9'hF0   ),
    //.VS_END   ( 9'h8   ),
    .HS_START ( 9'h080 )
) u_timer(
    .clk       ( clk      ),
    .pxl_cen   ( pxl_cen  ),
    .vdump     ( vdump    ),
    .H         ( hdump    ),
    .Hinit     ( hstart   ),
    .LHBL      ( preLHBL  ),
    .LVBL      ( preLVBL  ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          ),
    .vrender   ( vrender  ),
    .vrender1  (          )
);

jts16_mmr #(.MODEL(MODEL)) u_mmr(
    .rst       ( rst            ),
    .clk       ( clk            ),

    .flip      ( flip           ),
    // CPU interface
    .char_cs   ( char_cs        ),
    .cpu_addr  ( cpu_addr[11:1] ),
    .cpu_dout  ( cpu_dout       ),
    .dswn      ( dswn           ),

    // Video registers
    .scr1_pages ( scr1_pages    ),
    .scr2_pages ( scr2_pages    ),
    .scr1_hpos  ( scr1_hpos     ),
    .scr1_vpos  ( scr1_vpos     ),
    .scr2_hpos  ( scr2_hpos     ),
    .scr2_vpos  ( scr2_vpos     ),

    .rowscr1_en ( rowscr1_en    ),
    .rowscr2_en ( rowscr2_en    ),
    .colscr1_en ( colscr1_en    ),
    .colscr2_en ( colscr2_en    ),
    .altscr1_en ( altscr1_en    ),
    .altscr2_en ( altscr2_en    ),

    .st_addr    ( st_addr       ),
    .st_dout    ( st_dout       )
);

jts16_char #(.MODEL(MODEL)) u_char(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .pxl2_cen  ( pxl2_cen       ),
    .pxl_cen   ( pxl_cen        ),

    .alt_en    ( alt_en         ),
    // CPU interface
    .char_cs   ( char_cs        ),
    .cpu_addr  ( cpu_addr[11:1] ),
    .cpu_dout  ( cpu_dout       ),
    .dswn      ( dswn           ),
    .cpu_din   ( char_dout      ),

    // SDRAM interface
    .char_ok   ( char_ok        ),
    .char_addr ( char_addr      ), // 9 addr + 3 vertical + 2 horizontal = 14 bits
    .char_data ( char_data      ),

    // In-RAM data
    .scr_start ( scr_start      ),
    .rowscr1   ( rowscr1        ),
    .rowscr2   ( rowscr2        ),
    .altscr1   ( altscr1_en     ),
    .altscr2   ( altscr2_en     ),

    .scr1_hscan( scr1_hscan     ),
    .scr2_hscan( scr2_hscan     ),
    .colscr1   ( colscr1        ),
    .colscr2   ( colscr2        ),

    .col_busy1 ( col_busy1      ),
    .col_busy2 ( col_busy2      ),

    // Video signal
    .flip      ( flipx          ),
    .vrender   ( vrender        ),
    .vdump     ( vdump          ),
    .hdump     ( hdump          ),
    .pxl       ( char_pxl       ),
    .debug_bus ( debug_bus      )
);

jts16_scr #(.PXL_DLY(SCR1_DLY),.HB_END(HB_END),.MODEL(MODEL)) u_scr1(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .pxl2_cen  ( pxl2_cen       ),
    .pxl_cen   ( pxl_cen        ),
    //.LHBL      ( LHBL           ),
    .LHBL      ( ~scr_start     ),
    .alt_en    ( alt_en         ),

    .pages     ( scr1_pages     ),
    .hscr      ( scr1_hpos      ),
    .vscr      ( scr1_vpos      ),
    .rowscr_en ( rowscr1_en     ),
    .rowscr    ( rowscr1        ),

    .hcolscr   ( scr1_hscan     ),
    .colscr_en ( colscr1_en     ),
    .colscr    ( colscr1        ),
    .col_busy  ( col_busy1      ),

    // SDRAM interface
    .map_ok    ( map1_ok        ),
    .map_addr  ( map1_addr      ), // 3 pages + 11 addr = 14 (32 kB)
    .map_data  ( map1_data      ),

    .scr_ok    ( scr1_ok        ),
    .scr_addr  ( scr1_addr      ), // 1 bank + 12 addr + 3 vertical = 15 bits
    .scr_data  ( scr1_data      ),

    // Video signal
    .flip      ( flipx          ),
    .vrender   ( vrender        ),
    .hdump     ( hdump          ),
    .pxl       ( scr1_pxl       ),
    .debug_bus ( debug_bus      ),
    .bad       ( scr1_bad       )
);

jts16_scr #(.PXL_DLY(SCR2_DLY[8:0]),.MODEL(MODEL)) u_scr2(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .pxl2_cen  ( pxl2_cen       ),
    .pxl_cen   ( pxl_cen        ),
    //.LHBL      ( LHBL           ),
    .LHBL      ( ~scr_start     ),
    .alt_en    ( alt_en         ),

    .pages     ( scr2_pages     ),
    .hscr      ( scr2_hpos      ),
    .vscr      ( scr2_vpos      ),
    .rowscr_en ( rowscr2_en     ),
    .rowscr    ( rowscr2        ),

    .hcolscr   ( scr2_hscan     ),
    .colscr_en ( colscr2_en     ),
    .colscr    ( colscr2        ),
    .col_busy  ( col_busy2      ),

    // SDRAM interface
    .map_ok    ( map2_ok        ),
    .map_addr  ( map2_addr      ), // 3 pages + 11 addr = 14 (32 kB)
    .map_data  ( map2_data      ),

    .scr_ok    ( scr2_ok        ),
    .scr_addr  ( scr2_addr      ), // 1 bank + 12 addr + 3 vertical = 15 bits
    .scr_data  ( scr2_data      ),

    // Video signal
    .flip      ( flipx          ),
    .vrender   ( vrender        ),
    .hdump     ( hdump          ),
    .pxl       ( scr2_pxl       ),
    .debug_bus ( debug_bus      ),
    .bad       ( scr2_bad       )
);

jts16_prio u_prio(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .pxl2_cen  ( pxl2_cen       ),
    .pxl_cen   ( pxl_cen        ),

    .char_pxl  ( char_pxl       ),
    .scr1_pxl  ( scr1_pxl       ),
    .scr2_pxl  ( scr2_pxl       ),
    .obj_pxl   ( obj_pxl        ),

    // Set top priority
    .set_fix   ( set_fix        ),

    // Selected layer
    .sa        ( sa             ),
    .sb        ( sb             ),
    .fix       ( fix            ),

    .pal_addr  ( pal_addr       ),
    .shadow    ( shadow         ),
    .gfx_en    ( gfx_en         )
);

endmodule