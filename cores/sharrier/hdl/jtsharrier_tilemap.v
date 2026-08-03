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

    Original author: Jose Tejada Gomez. Twitter: @topapate
    Modified for jtsharrier by: niknak
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

module jtsharrier_tilemap(
    input              rst,
    input              clk,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              pxl_cen,   // pixel clock enable

    // CPU interface
    input              dip_pause,
    input              char_cs,
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
    output             fix,     // CHAR selected (?)
    output             sa,      // SCR1 selected (?)
    output             sb,      // SCR2 selected (?)
    output             obj,     // OBJ  selected (?)
    output             tprio,   // priority bit of selected tile map layer
    output             s1_pri,
    output             s2_pri,
    // Set top priority
    input              set_fix,

    // Debug
    input       [ 3:0] gfx_en,
    input       [ 7:0] debug_bus,
    input              vfix_en,
    input       [ 7:0] st_addr,
    output      [ 7:0] st_dout,
    output reg  [ 7:0] gfx_dbg,   // scr2 GFX readback (debug_bus[7:5]==100)
    output             scr_bad
);

parameter MODEL = 1;
// Frame rate and horizontal frequency as the original
// "The sprite X position defines the starting location of the sprite. The
//  leftmost pixel of the screen is $00B6, and the rightmost is $1F5."
parameter [8:0] HB_END = 9'h0bf;
parameter       HS_END = 9'h09E; // for System 16B 4.8us measured in PCB

parameter [9:0] SCR2_DLY= MODEL ? 10'd9 : 10'd17;
parameter [9:0] SCR1_DLY= SCR2_DLY;
parameter [9:0] ROWSCR2_DLY = SCR2_DLY;
parameter [9:0] ROWSCR1_DLY = SCR1_DLY;

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


// Measured on PCB
// vint lasts 64us, starts one line before blanking
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
    .VS_START  ( 9'hEF  ),
    .VS_END    ( 9'hF3  ), // 4 lines
    .HS_START  ( 9'h080 ),
    .HS_END    ( HS_END )  // 4.8us measured in PCB
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

// ===========================================================================
// PAGE SWIZZLE. The Hang-On tilemap, like MAME's 16a path, uses a swizzled page
// convention, where jts16_scr indexes the raw pages word. Transform:
//   P = nibble_reverse( ((raw>>4)&0x0707) | ((raw<<4)&0x7070) )
// which lands jts16_scr's raw indexing on MAME's quadrants. Checked against the
// real 0x11/0x22/0x33 register readings.
wire [15:0] scr1_pg_sw = ((scr1_pages>>4)&16'h0707) | ((scr1_pages<<4)&16'h7070);
wire [15:0] scr2_pg_sw = ((scr2_pages>>4)&16'h0707) | ((scr2_pages<<4)&16'h7070);
// numpages==4 for TILEMAP_HANGON: MAME lays only pages 0..3 into tileram and does
// `pages &= 0x3333`, so a page nibble is 2-bit. jts16_scr allows 3 bits; without
// this mask a nibble >=4 walks into the unpopulated upper 16 KB of the 32 KB
// scroll RAM and draws blank tiles. 0x3333 is nibble-symmetric, so it can be
// applied before the nibble-reverse.
wire [15:0] scr1_pg_m  = scr1_pg_sw & 16'h3333;
wire [15:0] scr2_pg_m  = scr2_pg_sw & 16'h3333;
wire [15:0] scr1_pages_x = { scr1_pg_m[3:0], scr1_pg_m[7:4], scr1_pg_m[11:8], scr1_pg_m[15:12] };
wire [15:0] scr2_pages_x = { scr2_pg_m[3:0], scr2_pg_m[7:4], scr2_pg_m[11:8], scr2_pg_m[15:12] };

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
    .st_dout    ( mmr_st_dout   )
);

// ---- scr2 MAP CONTENT PROBE ------------------------------------------------
// Counts non-blank scr2 tile fetches per frame, scaled /16. Read at st_addr 0x1F,
// so debug_bus = 0xBF. Separates a map that is missing content from one that
// holds it but does not render.
wire [7:0] mmr_st_dout;
reg  [15:0] nz_cnt,  gfx_cnt,  tot_cnt;
reg  [ 7:0] nz_latch, gfx_latch, tot_latch;
reg         vdl, m2okl, s2okl;
always @(posedge clk) begin
    vdl   <= vdump==9'd223;
    m2okl <= map2_ok;
    s2okl <= scr2_ok;
    if( (vdump==9'd223) & ~vdl ) begin
        nz_latch  <= nz_cnt[11:4];      // scr2 MAP non-blank codes /16       (0xBF)
        gfx_latch <= gfx_cnt[11:4];     // scr2 GFX non-blank fetches /16      (0xBE)
        tot_latch <= tot_cnt[11:4];     // scr2 GFX TOTAL fetches /16          (0xBD)
        nz_cnt <= 16'd0; gfx_cnt <= 16'd0; tot_cnt <= 16'd0;
    end else begin
        if( map2_ok & ~m2okl & (|map2_data)       & (nz_cnt !=16'hffff) ) nz_cnt  <= nz_cnt  + 1'b1;
        if( scr2_ok & ~s2okl & (|scr2_data[23:0]) & (gfx_cnt!=16'hffff) ) gfx_cnt <= gfx_cnt + 1'b1;
        if( scr2_ok & ~s2okl                       & (tot_cnt!=16'hffff) ) tot_cnt <= tot_cnt + 1'b1;
    end
end
assign st_dout = (st_addr[4:0]==5'h1f) ? nz_latch  :
                 (st_addr[4:0]==5'h1e) ? gfx_latch :
                 (st_addr[4:0]==5'h1d) ? tot_latch : mmr_st_dout;

// ---- scr2 GFX READBACK PROBE (debug_bus[7:5]==3'b100, read gfx_dbg via 0x80..0x87)
// Overrides scr2's GFX address, cycles 4 test tile codes at row 0 and latches
// plane0 (scr_data[7:0]) and plane2 (scr_data[23:16]). Expected, from
// epr-7196/7197/7198:
//   code 0x200/0x700/0x900/0xFF0 -> plane0 = D0 20 38 FF ; plane2 = 80 35 07 FF
wire [17:2] scr2_addr_u2;
wire        gfx_probe_en = debug_bus[7:5]==3'b100;
reg  [11:0] gcode;
reg  [1:0]  gsel;
reg  [12:0] gcnt;
reg  [7:0]  gp0_0,gp0_1,gp0_2,gp0_3, gp2_0,gp2_1,gp2_2,gp2_3;
always @(*) case(gsel)
    2'd0: gcode = 12'h200;
    2'd1: gcode = 12'h700;
    2'd2: gcode = 12'h900;
    default: gcode = 12'hFF0;
endcase
wire [17:2] probe_scr_addr = { 1'b0, gcode, 3'b000 };  // bank0, code, row0
assign scr2_addr = gfx_probe_en ? probe_scr_addr : scr2_addr_u2;
always @(posedge clk) begin
    if( !gfx_probe_en ) begin gcnt<=0; gsel<=0; end
    else begin
        gcnt <= gcnt + 1'b1;
        if( &gcnt ) gsel <= gsel + 1'b1;              // next code every 8192 clks
        if( gcnt[12:8]==5'b11111 && scr2_ok ) case(gsel)  // latch across a window
            2'd0: begin gp0_0<=scr2_data[7:0]; gp2_0<=scr2_data[23:16]; end
            2'd1: begin gp0_1<=scr2_data[7:0]; gp2_1<=scr2_data[23:16]; end
            2'd2: begin gp0_2<=scr2_data[7:0]; gp2_2<=scr2_data[23:16]; end
            default: begin gp0_3<=scr2_data[7:0]; gp2_3<=scr2_data[23:16]; end
        endcase
    end
end
always @(*) case(debug_bus[2:0])
    3'd0: gfx_dbg=gp0_0; 3'd1: gfx_dbg=gp0_1; 3'd2: gfx_dbg=gp0_2; 3'd3: gfx_dbg=gp0_3;
    3'd4: gfx_dbg=gp2_0; 3'd5: gfx_dbg=gp2_1; 3'd6: gfx_dbg=gp2_2; default: gfx_dbg=gp2_3;
endcase

jtsharrier_char #(.MODEL(MODEL)) u_char(
    .vfix_en   ( vfix_en        ),
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

jtsharrier_scr #(.PXL_DLY(SCR1_DLY),.ROW_PXL_DLY(ROWSCR1_DLY),.HB_END(HB_END),.MODEL(MODEL)) u_scr1(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .pxl2_cen  ( pxl2_cen       ),
    .pxl_cen   ( pxl_cen        ),
    .LHBL      ( preLHBL        ),
    .LVBL      ( preLVBL        ),

    .start     ( scr_start      ),
    .alt_en    ( alt_en         ),

    .pages     ( scr1_pages_x   ),
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

jtsharrier_scr #(.PXL_DLY(SCR2_DLY[8:0]),.ROW_PXL_DLY(ROWSCR2_DLY[8:0]),.MODEL(MODEL)) u_scr2(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .pxl2_cen  ( pxl2_cen       ),
    .pxl_cen   ( pxl_cen        ),
    .LHBL      ( preLHBL        ),
    .LVBL      ( preLVBL        ),

    .start     ( scr_start      ),
    .alt_en    ( alt_en         ),

    .pages     ( scr2_pages_x   ),
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
    .scr_addr  ( scr2_addr_u2   ), // overridable by the GFX readback probe
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
    .obj       ( obj            ),
    .sa        ( sa             ),
    .sb        ( sb             ),
    .fix       ( fix            ),
    .tprio     ( tprio          ),
    .scr1_prio ( s1_pri         ),
    .scr2_prio ( s2_pri         ),

    .pal_addr  ( pal_addr       ),
    .shadow    ( shadow         ),
    .gfx_en    ( gfx_en         )
);

endmodule