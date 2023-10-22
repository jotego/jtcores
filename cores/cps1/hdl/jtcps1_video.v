/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-1-2020 */


// Scroll 1 is 512x512, 8x8 tiles
// Scroll 2 is 1024x1024 16x16 tiles
// Scroll 3 is 2048x2048 32x32 tiles

module jtcps1_video(
    input              rst,
    input              clk,
    input              clk_cpu,
    input              pxl2_cen,        // pixel clock enable
    input              pxl_cen,        // pixel clock enable

    output     [ 8:0]  vdump,
    output     [ 8:0]  vrender,
    output     [ 8:0]  hdump,
    input      [ 3:0]  gfx_en,
    input      [ 7:0]  debug_bus,

    `ifdef CPS2
    input              objcfg_cs,
    input              obank,
    output     [12:0]  oram_addr,
    input              oram_ok,
    output             oram_clr,
    output             oram_cs,
    input      [15:0]  oram_data,
    `endif

    // CPU interface
    input              ppu_rstn,
    input              ppu1_cs,
    input              ppu2_cs,
    input   [12:1]     addr,
    input   [ 1:0]     dsn,      // data select, active low
    input   [15:0]     cpu_dout,
    output  [15:0]     mmr_dout,
    output             cpu_speed,
    output             charger,
    output             kabuki_en,
    output             raster,
    output             star_bank,

    // BUS sharing
    output             busreq,
    input              busack,

    // CPS-B Registers
    input              cfg_we,
    input      [ 7:0]  cfg_data,

    // Extra inputs read through the C-Board
    input   [ 3:0]  cab_1p,
    input   [ 3:0]  coin,
    input   [ 9:0]  joystick1,
    input   [ 9:0]  joystick2,
    input   [ 9:0]  joystick3,
    input   [ 9:0]  joystick4,

    // Video RAM interface
    output     [17:1]  vram_dma_addr,
    input      [15:0]  vram_dma_data,
    input              vram_dma_ok,
    output             vram_dma_cs,
    output             vram_dma_clr,
    output             vram_rfsh_en,

    // Video signal
    output             HS,
    output             VS,
    output             LHBL,
    output             LVBL,
    output     [ 7:0]  red,
    output     [ 7:0]  green,
    output     [ 7:0]  blue,
    output             flip,

    // GFX ROM interface
    output     [19:0]  rom1_addr,
    output             rom1_half,    // selects which half to read
    input      [31:0]  rom1_data,
    output             rom1_cs,
    input              rom1_ok,

    output     [19:0]  rom0_addr,
    output     [ 1:0]  rom0_bank,
    output             rom0_half,    // selects which half to read
    input      [31:0]  rom0_data,
    output             rom0_cs,
    input              rom0_ok,

    output     [12:0]  star0_addr,
    input      [31:0]  star0_data,
    output             star0_cs,
    input              star0_ok,

    output     [12:0]  star1_addr,
    input      [31:0]  star1_data,
    output             star1_cs,
    input              star1_ok,

    input              watch_vram_cs,
    output             watch

    `ifdef CPS1
    // EEPROM
    ,output            sclk,
    output             sdi,
    output             scs,
    input              sdo
    `endif
);

parameter REGSIZE=24;

`ifdef CPS2
localparam OBJW=12, BLNK_DLY=5;
`else
localparam OBJW=9, BLNK_DLY=4;
`endif

// use for CPU only simulations:
`ifdef NOVIDEO
`define NOSCROLL
`define NOOBJ
`define NOCOLMIX
`endif

wire [    11:0] pal_addr, merge_pxl, final_pxl;
wire [    10:0] scr1_pxl, scr2_pxl, scr3_pxl;
wire [     6:0] star1_pxl, star0_pxl;
wire [     8:0] vrender1;
wire [    15:0] ppu_ctrl, pal_raw;
wire [    17:1] vram_pal_addr;
wire            line_start, frame_start, preVB;
wire            busack_obj, busack_pal;
wire [OBJW-1:0] obj_pxl;
wire [     1:0] star_en;

// Register configuration
// Scroll
wire       [15:0]  hpos1, hpos2, hpos3, vpos1, vpos2, vpos3, hstar1, hstar0, vstar1, vstar0;
// VRAM position
wire       [15:0]  vram1_base, vram2_base, vram3_base, vram_obj_base, vram_row_base, row_offset;
// Layer priority
wire       [15:0]  layer_ctrl, prio0, prio1, prio2, prio3;
wire       [ 7:0]  layer_mask0, layer_mask1, layer_mask2, layer_mask3, layer_mask4;
// palette control
wire       [15:0]  pal_base;
wire               pal_dma_ok;
wire       [ 5:0]  pal_page_en; // which palette pages to copy
// ROM banks
wire       [ 5:0]  game;
wire       [15:0]  bank_offset;
wire       [15:0]  bank_mask;

wire       [ 7:0]  tile_addr;
wire       [15:0]  tile_data, row_scr;
wire       [ 9:0]  obj_cache_addr;
wire               obj_dma_ok;
wire       [15:0]  objtable_data;

wire               objdma_en, row_en;
wire       [ 3:1]  scrdma_en;
wire               star1_precs, star0_precs;
wire               line_inc, VB, HB;

`ifdef CPS2
    assign obj_dma_ok = 0;
    assign star1_cs   = 0;
    assign star0_cs   = 0;
`else
    assign star1_cs   = ~VB & star1_precs;// & star_en[1];
    assign star0_cs   = ~VB & star0_precs;// & star_en[0];
`endif

wire               watch_scr1, watch_scr2, watch_scr3,
                   watch_pal, watch_row, watch_obj;

`ifdef CPS2
assign objdma_en = 0; // People said that Progear was too slow
`else
assign objdma_en = 1; // does this signal exist?
`endif
assign scrdma_en = ppu_ctrl[3:1];
assign row_en    = ppu_ctrl[0];
assign flip      = ppu_ctrl[15];

`ifdef JTCPS_WATCH
jtcps1_watch u_watch(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .HB             ( HB            ),
    .VB             ( VB            ),

    .watch_scr1     ( watch_scr1    ),
    .watch_scr2     ( watch_scr2    ),
    .watch_scr3     ( watch_scr3    ),
    .watch_pal      ( watch_pal     ),
    .watch_row      ( watch_row     ),
    .watch_obj      ( watch_obj     ),
    .watch_vram_cs  ( watch_vram_cs ),
    .pal_dma_ok     ( pal_dma_ok    ),

    .raster         ( raster        ),

    .ppu1_cs        ( ppu1_cs       ),
    .ppu2_cs        ( ppu2_cs       ),
    .objcfg_cs      ( objcfg_cs     ),

    .watch          ( watch         )
);
`else
assign watch=0;
`endif

jtcps1_dma u_dma(
    .rst            ( rst               ),
    .clk            ( clk               ),
    .pxl2_cen       ( pxl2_cen          ),
    .pxl_cen        ( pxl_cen           ),
    .HB             ( HB                ),
    .vrender1       ( vrender1          ),
    .flip           ( flip              ),

    .tile_addr      ( tile_addr         ),
    .tile_data      ( tile_data         ),

    .scrdma_en      ( scrdma_en         ),
    .vram1_base     ( vram1_base        ),
    .hpos1          ( hpos1             ),
    .vpos1          ( vpos1             ),

    .vram2_base     ( vram2_base        ),
    .hpos2          ( hpos2             ),
    .vpos2          ( vpos2             ),

    .vram3_base     ( vram3_base        ),
    .hpos3          ( hpos3             ),
    .vpos3          ( vpos3             ),

    // Row Scroll
    .vram_row_base  ( vram_row_base     ),
    .row_offset     ( row_offset        ),
    .row_en         ( row_en            ),
    .row_scr        ( row_scr           ),

    // Palette
    .vram_pal_base  ( pal_base          ),
    .pal_dma_ok     ( pal_dma_ok        ),
    .pal_page_en    ( pal_page_en       ),
    .pal_data       ( pal_raw           ),
    .colmix_addr    ( pal_addr          ),

    // Objects
    .objdma_en      ( objdma_en         ),
    .vram_obj_base  ( vram_obj_base     ),
    `ifdef CPS2
        .obj_table_addr ( 10'd0         ),
    `else
        .obj_table_addr (obj_cache_addr ),
    `endif
    .obj_table_data ( objtable_data     ),
    .obj_dma_ok     ( obj_dma_ok        ),

    .br             ( busreq            ),
    .bg             ( busack            ),
    .vram_addr      ( vram_dma_addr     ),
    .vram_data      ( vram_dma_data     ),
    .vram_ok        ( vram_dma_ok       ),
    .vram_clr       ( vram_dma_clr      ),
    .vram_cs        ( vram_dma_cs       ),
    .rfsh_en        ( vram_rfsh_en      ),

    // watched signals
    .watch_scr1     ( watch_scr1        ),
    .watch_scr2     ( watch_scr2        ),
    .watch_scr3     ( watch_scr3        ),
    .watch_pal      ( watch_pal         ),
    .watch_row      ( watch_row         ),
    .watch_obj      ( watch_obj         )
);

jtcps1_timing u_timing(
    .clk            ( clk               ),
    .cen8           ( pxl_cen           ),

    .vdump          ( vdump             ),
    .hdump          ( hdump             ),
    .vrender1       ( vrender1          ),
    .vrender        ( vrender           ),
    .line_inc       ( line_inc          ),
    .line_start     ( line_start        ),
    .frame_start    ( frame_start       ),
    // to video output
    .HS             ( HS                ),
    .VS             ( VS                ),
    .VB             ( VB                ),
    .preVB          ( preVB             ),
    .HB             ( HB                ),
    .debug_bus      ( debug_bus         )
);

// initial begin
//     $display("OFFSET=%X",`OFFSET);
// end

jtcps1_mmr #(REGSIZE) u_mmr(
    .rst            ( rst               ),
    .clk            ( clk               ),
    .pxl_cen        ( pxl_cen           ),
    .ppu_rstn       ( ppu_rstn          ),  // controlled by CPU

    .frame_start    ( frame_start       ),
    .line_inc       ( line_inc          ),
    .raster         ( raster            ),
    //.debug_bus      ( debug_bus         ),

    .ppu1_cs        ( ppu1_cs           ),
    .ppu2_cs        ( ppu2_cs           ),
    .addr           ( addr[5:1]         ),
    .dsn            ( dsn               ),      // data select, active low
    .cpu_dout       ( cpu_dout          ),
    .mmr_dout       ( mmr_dout          ),
    // registers
    .ppu_ctrl       ( ppu_ctrl          ),
    .star_bank      ( star_bank         ),
    // Scroll
    .hpos1          ( hpos1             ),
    .hpos2          ( hpos2             ),
    .hpos3          ( hpos3             ),
    .vpos1          ( vpos1             ),
    .vpos2          ( vpos2             ),
    .vpos3          ( vpos3             ),
    .hstar1         ( hstar0            ),
    .hstar2         ( hstar1            ),
    .vstar1         ( vstar0            ),
    .vstar2         ( vstar1            ),

    .cpu_speed      ( cpu_speed         ),
    .charger        ( charger           ),
    .kabuki_en      ( kabuki_en         ),

    // OBJ DMA
    `ifndef CPS2
        `ifndef NOMAIN
            .obj_dma_ok ( obj_dma_ok    ),
        `else
            .obj_dma_ok (               ),
        `endif
    `else
        .obj_dma_ok (                   ),
    `endif

    .cab_1p   ( cab_1p      ),
    .coin     ( coin        ),
    .joystick1      ( joystick1         ),
    .joystick2      ( joystick2         ),
    .joystick3      ( joystick3         ),
    .joystick4      ( joystick4         ),

    // ROM banks
    .game           ( game              ),
    .bank_offset    ( bank_offset       ),
    .bank_mask      ( bank_mask         ),

    // VRAM position
    .vram1_base     ( vram1_base        ),
    .vram2_base     ( vram2_base        ),
    .vram3_base     ( vram3_base        ),
    .vram_obj_base  ( vram_obj_base     ),
    .vram_row_base  ( vram_row_base     ),
    .row_offset     ( row_offset        ),
    .pal_base       ( pal_base          ),
`ifndef NOMAIN
    .pal_copy       ( pal_dma_ok        ),
`else
    .pal_copy       (                   ),
`endif

    // CPS-B Registers
    .cfg_we         ( cfg_we            ),
    .cfg_data       ( cfg_data          ),

    .layer_ctrl     ( layer_ctrl        ),
    .layer_mask0    ( layer_mask0       ),
    .layer_mask1    ( layer_mask1       ),
    .layer_mask2    ( layer_mask2       ),
    .layer_mask3    ( layer_mask3       ),
    .layer_mask4    ( layer_mask4       ),
    .prio0          ( prio0             ),
    .prio1          ( prio1             ),
    .prio2          ( prio2             ),
    .prio3          ( prio3             ),
    .pal_page_en    ( pal_page_en       )
    `ifdef CPS1
    ,.sclk          ( sclk              ),
    .sdi            ( sdi               ),
    .sdo            ( sdo               ),
    .scs            ( scs               )
    `endif
);

//`define NOSCROLL1
`ifndef NOSCROLL
jtcps1_scroll u_scroll(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .gfx_en     ( gfx_en        ),
    .flip       ( flip          ),

    .vrender    ( vrender       ),
    .vdump      ( vdump         ),
    .hdump      ( hdump         ),
    .preVB      ( preVB         ),
    .VB         ( VB            ),
    .HB         ( HB            ),
    .HS         ( HS            ),

    .hpos1      ( hpos1         ),
    .vpos1      ( vpos1         ),

    .hpos2      ( row_scr       ),
    .vpos2      ( vpos2         ),

    .hpos3      ( hpos3         ),
    .vpos3      ( vpos3         ),

    .hstar0     ( hstar0        ),
    .vstar0     ( vstar0        ),
    .hstar1     ( hstar1        ),
    .vstar1     ( vstar1        ),

    // ROM banks
    .game       ( game          ),
    .bank_offset( bank_offset   ),
    .bank_mask  ( bank_mask     ),

    .start      ( line_start    ),

    .tile_addr  ( tile_addr     ),
    .tile_data  ( tile_data     ),

    .rom_addr   ( rom1_addr     ),
    .rom_data   ( rom1_data     ),
    .rom_cs     ( rom1_cs       ),
    .rom_ok     ( rom1_ok       ),
    .rom_half   ( rom1_half     ),

    .star0_addr ( star0_addr    ),
    .star0_data ( star0_data    ),
    .star0_ok   ( star0_ok      ),
    .star0_cs   ( star0_precs   ),

    .star1_addr ( star1_addr    ),
    .star1_data ( star1_data    ),
    .star1_ok   ( star1_ok      ),
    .star1_cs   ( star1_precs   ),

    .scr1_pxl   ( scr1_pxl      ),
    .scr2_pxl   ( scr2_pxl      ),
    .scr3_pxl   ( scr3_pxl      ),

    .star0_pxl  ( star0_pxl     ),
    .star1_pxl  ( star1_pxl     ),
    .debug_bus  ( debug_bus     )
);
`else
assign rom1_cs    = 1'b0;
assign rom1_addr  = 20'd0;
assign scr1_pxl   = 11'h1ff;
assign scr2_pxl   = 11'h1ff;
assign scr3_pxl   = 11'h1ff;
`endif

// Objects
`ifndef CPS2
    jtcps1_obj u_obj(
        .rst        ( rst           ),
        .clk        ( clk           ),
        .pxl_cen    ( pxl_cen       ),
        .flip       ( flip          ),

        // Cache access
        .frame_addr ( obj_cache_addr),
        .frame_data ( objtable_data ),

        .start      ( line_start    ),
        .vrender    ( vrender       ),
        .vdump      ( vdump         ),
        .hdump      ( hdump         ),

        // ROM banks
        .game       ( game          ),
        .bank_offset( bank_offset   ),
        .bank_mask  ( bank_mask     ),

        // ROM data
        .rom_addr   ( rom0_addr     ),
        .rom_data   ( rom0_data     ),
        .rom_cs     ( rom0_cs       ),
        .rom_ok     ( rom0_ok       ),
        .rom_half   ( rom0_half     ),

        .pxl        ( obj_pxl       )
    );

    assign rom0_bank = 2'b10;
`else
    jtcps2_obj u_obj(
        .rst        ( rst           ),
        .clk        ( clk           ),
        .clk_cpu    ( clk_cpu       ),
        .pxl_cen    ( pxl_cen       ),
        .flip       ( flip          ),
        .LVBL       ( ~VB           ),

        .objcfg_cs  ( objcfg_cs     ),
        .addr       ( addr[3:1]     ),
        .dsn        ( dsn           ),
        .cpu_dout   ( cpu_dout      ),

        .obank      ( obank         ),
        // Interface with SDRAM for OBJRAM
        .oram_addr  ( oram_addr     ),
        .oram_ok    ( oram_ok       ),
        .oram_data  ( oram_data     ),
        .oram_clr   ( oram_clr      ),
        .oram_cs    ( oram_cs       ),

        .start      ( line_start    ),
        .vrender1   ( vrender1      ),
        .vdump      ( vdump         ),
        .hdump      ( hdump         ),

        // ROM data
        .rom_addr   ( rom0_addr     ),
        .rom_bank   ( rom0_bank     ),
        .rom_data   ( rom0_data     ),
        .rom_cs     ( rom0_cs       ),
        .rom_ok     ( rom0_ok       ),
        .rom_half   ( rom0_half     ),

        .pxl        ( obj_pxl       )
    );
`endif

`ifndef NOCOLMIX
jtcps1_colmix u_colmix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .gfx_en     ( gfx_en        ),
    .scrdma_en  ( scrdma_en     ),
    .star_en    ( star_en       ),

    // Layer priority
    .layer_ctrl ( layer_ctrl    ),
    .layer_mask0( layer_mask0   ),
    .layer_mask1( layer_mask1   ),
    .layer_mask2( layer_mask2   ),
    .layer_mask3( layer_mask3   ),
    .layer_mask4( layer_mask4   ),
    .prio0      ( prio0         ),
    .prio1      ( prio1         ),
    .prio2      ( prio2         ),
    .prio3      ( prio3         ),

    // Pixel layers data
    .scr1_pxl   ( scr1_pxl      ),
    .scr2_pxl   ( scr2_pxl      ),
    .scr3_pxl   ( scr3_pxl      ),
    .star0_pxl  ( star0_pxl     ),
    .star1_pxl  ( star1_pxl     ),
    `ifndef CPS2
    .obj_pxl    ( obj_pxl       ),
    `else
    .obj_pxl    ( 9'h00f        ),
    `endif

    .pxl        ( merge_pxl     )
);

`ifdef CPS2
jtcps2_colmix u_objmix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .objcfg_cs  ( objcfg_cs     ),
    .addr       ( addr[3:1]     ),
    .cpu_dout   ( cpu_dout      ),
    .dsn        ( dsn           ),
    .layer_ctrl ( layer_ctrl    ),

    .scr_pxl    ( merge_pxl     ),
    .obj_pxl    ( obj_pxl       ),
    .obj_en     ( gfx_en[3]     ),
    .pxl        ( final_pxl     ),
    .debug_bus  ( debug_bus     )
);
`else
assign final_pxl = merge_pxl;
`endif

jtcps1_pal #(.BLNK_DLY(BLNK_DLY)) u_pal(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .vb         ( VB            ),
    .hb         ( HB            ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),

    // Palette RAM
    .pxl_in     ( final_pxl     ),
    .pal_addr   ( pal_addr      ),
    .pal_raw    ( pal_raw       ),

    // Video
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

`else
assign red_colmix  = 8'b0;
assign green_colmix= 8'b0;
assign blue_colmix = 8'b0;
assign LHBL_colmix = ~HB;
assign LVBL_colmix = ~VB;
assign vpal_cs   = 1'b0;
assign vpal_addr = 17'd0;
assign LVBL_dly  = ~VB;
assign LHBL_dly  = ~HB;
`endif

// Fake DMA signals to allow for video-only simulation
`ifdef  NOMAIN
reg fake_pal, last_VB;

assign pal_dma_ok = fake_pal;
assign obj_dma_ok = fake_pal;

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        fake_pal <= 0;
        last_VB  <= 1;
    end else if(pxl_cen) begin
        last_VB  <= VB;
        fake_pal <= VB && !last_VB;
    end
end
`endif

endmodule