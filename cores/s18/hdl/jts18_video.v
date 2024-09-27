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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 29-4-2024 */

module jts18_video(
    input              rst,
    input              clk96,
    input              clk48,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              pxl_cen,   // pixel clock enable
    // pixel clock enable at 48 MHz
    input              pxl2_48cen,
    input              pxl_48cen,

    // video configuration
    input              flip,
    inout              ext_flip,
    input              vdp_en,
    input              vid16_en,
    input              gray_n,
    input      [ 7:0]  tile_bank,
    input      [ 7:0]  game_id,
    output     [ 8:0]  vrender,

    // CPU interface
    input              dip_pause,
    input              bank_cs,
    input              char_cs,
    input              objram_cs,
    input      [23:1]  addr,
    input      [15:0]  din,
    input      [ 1:0]  dsn,
    input              rnw,
    input              asn,
    output             vdp_dtackn,

    output     [15:0]  char_dout,
    output     [15:0]  obj_dout,
    output     [15:0]  vdp_dout,
    input      [ 2:0]  vdp_prio,
    output             vint,

    // palette RAM
    output     [10:0]  pal_addr,
    input      [15:0]  pal_dout,

    // SDRAM interface
    input              char_ok,
    output     [21:2]  char_addr, // 9 addr + 3 vertical + 2 horizontal = 14 bits
    input      [31:0]  char_data,

    input              map1_ok,
    output     [15:1]  map1_addr, // 3 pages + 11 addr = 14 (32 kB)
    input      [15:0]  map1_data,

    input              scr1_ok,
    output     [21:2]  scr1_addr, // 1 bank + 12 addr + 3 vertical = 15 bits
    input      [31:0]  scr1_data,

    input              map2_ok,
    output     [15:1]  map2_addr, // 3 pages + 11 addr = 14 (32 kB)
    input      [15:0]  map2_data,

    input              scr2_ok,
    output     [21:2]  scr2_addr, // 1 bank + 12 addr + 3 vertical = 15 bits
    input      [31:0]  scr2_data,

    input              obj_ok,
    output             obj_cs,
    output     [22:1]  obj_addr,
    input      [15:0]  obj_data,

    input       [2:0]  lightguns,

    // Video signal
    output             HS,
    output             VS,
    output             LHBL,
    output             LVBL,
    output     [ 7:0]  red,
    output     [ 7:0]  green,
    output     [ 7:0]  blue,

    // Debug
    input      [ 3:0]  gfx_en,
    input      [ 7:0]  debug_bus,
    // status dump
    input      [ 7:0]  st_addr,
    input      [ 1:0]  joystick1,
    output     [ 7:0]  st_dout
);

localparam       PCB_5874 = 0,  // refers to the bit in game_id
                 PCB_5987_DESERTBR = 1,
                 PCB_5987 = 2,
                 PCB_7525 = 3,  // hamaway
                 PCB_5873 = 4,  // lghost
                 PCB_7248 = 5;  // shdancer

wire [5:0] s16_r, s16_g, s16_b;
wire [7:0] vdp_r, vdp_g, vdp_b;
wire [7:0] st_s16, st_vdp;
wire [8:0] hdump, vdump;
wire       vdp_hs, vdp_vs, vdp_hde, vdp_vde, vdp_spa_b, vdp_ysn;
wire       scr_hs, scr_vs, scr_lvbl, scr_lhbl;
wire       LHBL_dly, LVBL_dly, HS48, VS48, LHBL48, LVBL48,
           scr1_sel, scr2_sel, vdp_on,
           sa, sb, fix, s1_pri, s2_pri;
wire [1:0] obj_prio;
wire [2:0] scr1_bank, scr2_bank;
wire [3:0] obj_bank;
(* ramstyle = "logic" *) reg  [7:0] tilebanks[16];

wire       alt_gfx = game_id[PCB_5987_DESERTBR]|game_id[PCB_5987]|game_id[PCB_7525];

always @(posedge clk48)
   if (bank_cs) tilebanks[addr[4:1]] <= game_id[PCB_7525] ? (din[7] ? {3'd0, din[4:0]} + 8'h20 : {3'd0, din[4:0]}) : din[7:0];
wire [7:0] st_show;
assign st_dout = st_show;//{3'd0, vdp_en, 3'd0,vdp_on};
assign scr1_sel = scr1_bank[2];
assign scr2_sel = scr2_bank[2];

assign char_addr[21:14] = alt_gfx ? {tilebanks[0][6:0], 1'b0} : 8'd0;
assign scr1_addr[21:15] = alt_gfx ? tilebanks[{1'b0, scr1_bank}][6:0] : {1'b0, scr1_sel ? tile_bank[7:4] : tile_bank[3:0], scr1_bank[1:0]};
assign scr2_addr[21:15] = alt_gfx ? tilebanks[{1'b0, scr2_bank}][6:0] : {1'b0, scr2_sel ? tile_bank[7:4] : tile_bank[3:0], scr2_bank[1:0]};

assign obj_addr[22:17] = (game_id[PCB_5987_DESERTBR]|game_id[PCB_5987]) ? {tilebanks[{1'b1, obj_bank[3:1]}][4:0], obj_bank[0]} : {2'd0, obj_bank};

`ifndef NOVDP
assign VS   = scr_vs;   // gfx_en[2] ? scr_vs   : vdp_vs;
assign HS   = scr_hs;   // gfx_en[2] ? scr_hs   : vdp_hs;
assign LVBL = scr_lvbl; // gfx_en[2] ? scr_lvbl : vdp_vde;
assign LHBL = scr_lhbl; // gfx_en[2] ? scr_lhbl : vdp_hde;
`else
assign VS   = scr_vs;
assign HS   = scr_hs;
assign LVBL = scr_lvbl;
assign LHBL = scr_lhbl;
`endif

// always @(posedge clk) begin
//     if(pxl_cen) begin
//         HS <= HS48;
//         VS <= VS48;
//         LHBL <= LHBL48;
//         LVBL <= LVBL48;
//     end
// end

/* verilator tracing_on */
jts18_video16 u_video16(
    .rst        ( rst       ),
    .clk        ( clk48     ),
    .pxl2_cen   ( pxl2_48cen),
    .pxl_cen    ( pxl_48cen ),

    .video_en   ( vid16_en  ),
    .flip       ( flip      ),
    .gray_n     ( gray_n    ),

    .pal_addr   ( pal_addr  ),
    .pal_dout   ( pal_dout  ),
    // CPU interface
    .dip_pause  ( dip_pause ),
    .char_cs    ( char_cs   ),
    .objram_cs  ( objram_cs ),
    .addr       ( addr[12:1]),
    .din        ( din       ),
    .dsn        ( dsn | {2{rnw}}),

    .char_dout  ( char_dout ),
    .obj_dout   ( obj_dout  ),
    .vint       ( vint      ),

    // SDRAM interface
    .char_ok    ( char_ok   ),
    .char_addr  ( char_addr[13:2] ), // 9 addr + 3 vertical + 2 horizontal = 14 bits
    .char_data  ( char_data ),

    .map1_ok    ( map1_ok   ),
    .map1_addr  ( map1_addr ), // 3 pages + 11 addr = 14 (32 kB)
    .map1_data  ( map1_data ),

    .scr1_ok    ( scr1_ok   ),
    .scr1_addr  ({scr1_bank,scr1_addr[14:2]}), // 1 bank + 12 addr + 3 vertical = 15 bits
    .scr1_data  ( scr1_data ),

    .map2_ok    ( map2_ok   ),
    .map2_addr  ( map2_addr ), // 3 pages + 11 addr = 14 (32 kB)
    .map2_data  ( map2_data ),

    .scr2_ok    ( scr2_ok   ),
    .scr2_addr  ({scr2_bank,scr2_addr[14:2]}), // 1 bank + 12 addr + 3 vertical = 15 bits
    .scr2_data  ( scr2_data ),

    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( {obj_bank, obj_addr[16:1]} ),
    .obj_data   ( obj_data  ),

    // Video signal
    .sa         ( sa        ),
    .sb         ( sb        ),
    .fix        ( fix       ),
    .obj_prio   ( obj_prio  ),
    .tprio      (           ),
    .s1_pri     ( s1_pri    ),
    .s2_pri     ( s2_pri    ),
    .HS         ( scr_hs    ),
    .VS         ( scr_vs    ),
    .LHBL       ( scr_lhbl  ),
    .LVBL       ( scr_lvbl  ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .red        ( s16_r     ),
    .green      ( s16_g     ),
    .blue       ( s16_b     ),

    // Debug
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( 8'b0/*debug_bus*/ ),
    // status dump
    .st_addr    ( st_addr   ),
    .st_dout    ( st_s16    ),
    .scr_bad    (           )
);

// Megadrive VDP
/* verilator tracing_off */
jts18_vdp u_vdp(
    .rst        ( rst       ),
    .clk96      ( clk96     ),
    .clk48      ( clk48     ),
    // S16 video
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .s16b_vs    ( VS        ),
    .s16b_hs    ( HS        ),
    .pxl_cen    ( pxl_cen   ),
    // Main CPU interface
    .addr       ( addr      ),
    .din        ( din       ),
    .dout       ( vdp_dout  ),
    .rnw        ( rnw       ),
    .asn        ( asn       ),
    .dsn        ( dsn       ),
    .dtackn     ( vdp_dtackn),
    // Video output
    .hs         ( vdp_hs    ),
    .vs         ( vdp_vs    ),
    .hde        ( vdp_hde   ),
    .vde        ( vdp_vde   ),
    .red        ( vdp_r     ),
    .green      ( vdp_g     ),
    .blue       ( vdp_b     ),
    .spa_b      ( vdp_spa_b ),
    .ys_n       ( vdp_ysn   ),
    .video_en   ( vdp_on    ),
    .debug_bus  ( 8'b0/*debug_bus*/ ),
    .st_dout    ( st_vdp    )
);
/* verilator tracing_off */
jts18_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk48     ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),
    // VDP
    .vdp_en     ( vdp_en    ),
    .vdp_ysn    ( vdp_ysn   ),
    .vdp_prio   ( vdp_prio  ),
    .vid16_en   ( vid16_en  ),
    // Lighgun crosshairs
    .lightguns  ( lightguns & {3{game_id[PCB_5873]}} ),
    // S16 Video priority
    .sa         ( sa        ),
    .sb         ( sb        ),
    .fix        ( fix       ),
    .obj_prio   ( obj_prio  ),
    .s1_pri     ( s1_pri    ),
    .s2_pri     ( s2_pri    ),

    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .LHBL_dly   ( LHBL_dly  ),
    .LVBL_dly   ( LVBL_dly  ),
    .gfx_en     ( gfx_en    ),
    .s16_r      ( s16_r     ),
    .s16_g      ( s16_g     ),
    .s16_b      ( s16_b     ),
    .vdp_r      ( vdp_r     ),
    .vdp_g      ( vdp_g     ),
    .vdp_b      ( vdp_b     ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .debug_bus  ( 8'b0/*debug_bus*/ ),
    .st_show    ( st_show   ),
    .joystick1  ( joystick1 )
);

endmodule