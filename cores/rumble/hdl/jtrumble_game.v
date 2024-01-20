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
    Date: 5-4-2021 */

module jtrumble_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

localparam MAINW=18, RAMW=13, CHARW=13, SCRW=17, OBJW=17;

// ROM data
wire [15:0] char_data;
wire [15:0] scr_data;
wire [15:0] obj_data, obj_pre;
wire [ 7:0] main_data, obj_din;
wire [ 7:0] snd_data, snd_latch;
wire [ 7:0] cpu_dout, scr_dout, char_dout;
// ROM address
wire [17:0] main_addr;
wire [12:0] cpu_AB;
wire [14:0] snd_addr;
wire [ 8:0] obj_AB;
wire [CHARW-1:0] char_addr;
wire [SCRW-1:0] scr_addr;
wire [OBJW-1:0] obj_addr;
wire [ 7:0] dipsw_a, dipsw_b;
wire        cenfm, cpu_cen, loud;

wire [ 9:0] scr_hpos, scr_vpos;
wire [ 8:0] vdump;
wire        scr_busy, char_busy;

wire        main_rnw;
wire        main_ok, snd_ok, char_ok, scr_ok,
            obj_ok;
wire        main_cs, snd_cs, obj_cs,
            pal_cs, char_cs, scr_cs;

wire [ 1:0] prom_bank;
wire        prom_prior_we;

wire        vmid, cen24_8, cen24_4, cen24_2;
wire        sres_b, flip;
wire        bus_ack, bus_req, blcnten;

assign { dipsw_b, dipsw_a } = dipsw[15:0];
assign dip_flip = flip;
assign obj_cs   = 1;
assign debug_view = { 3'd0, loud, 3'd0, flip };

// Banks 1-3 unused for writting
assign ba1_din=0, ba2_din=0, ba3_din=0,
       ba1_dsn=3, ba2_dsn=3, ba3_dsn=3;
assign ba_wr[3:1]=0;

jtframe_cen48 u_cen48(
    .clk    ( clk      ),
    .cen16  ( pxl2_cen ),
    .cen16b (          ),
    .cen12  (          ),
    .cen12b (          ),
    .cen8   ( pxl_cen  ),
    .cen6   (          ),
    .cen6b  (          ),
    .cen4   (          ),
    .cen4_12(          ),
    .cen3   (          ),
    .cen3q  (          ),
    .cen3qb (          ),
    .cen3b  (          ),
    .cen1p5 (          ),
    .cen1p5b(          )
);

jtframe_cen24 u_cen24(
    .clk    ( clk24     ),
    .cen12  (           ),
    .cen8   ( cen24_8   ),
    .cen6   (           ),
    .cen4   ( cen24_4   ),
    .cen3   (           ),
    .cen3q  (           ),
    .cen1p5 (           ),
    .cen12b (           ),
    .cen6b  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5b(           )
);

jtframe_cendiv u_cendiv(
    .clk    ( clk24     ),
    .cen_in ( cen24_4   ),
    .cen_div(           ), // Divided but not alligned with the original
    .cen_da ( cen24_2   )
);

`ifndef NOMAIN
jtrumble_main u_main(
    .rst        ( rst24         ),
    .clk        ( clk24         ),
    .clk_obj    ( clk           ),
    .cen8       ( cen24_8       ),
    .cpu_cen    ( cpu_cen       ),
    .LVBL       ( LVBL          ),   // vertical blanking when 0
    .vmid       ( vmid          ),
    // Screen
    .pal_cs     ( pal_cs        ),
    .flip       ( flip          ),
    // Sound
    .sres_b     ( sres_b        ), // Z80 reset
    .snd_latch  ( snd_latch     ),
    // Characters
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    //.char_busy  ( char_busy     ),
    .char_busy  ( 1'b0     ),
    // scroll
    .scr_dout   ( scr_dout      ),
    .scr_cs     ( scr_cs        ),
    //.scr_busy   ( scr_busy      ),
    .scr_busy   ( 1'b0      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    // cabinet I/O
    .cab_1p      ( cab_1p       ),
    .coin        ( coin         ),
    .joystick1   ( joystick1    ),
    .joystick2   ( joystick2    ),
    // BUS sharing
    .bus_ack     ( bus_ack      ),
    .bus_req     ( bus_req      ),
    .obj_AB      ( obj_AB       ),
    .obj_din     ( obj_din      ),
    .RnW         ( main_rnw     ),
    .cpu_AB      ( cpu_AB       ),
    // ROM access
    .rom_cs      ( main_cs      ),
    .rom_addr    ( main_addr    ),
    .rom_data    ( main_data    ),
    .rom_ok      ( main_ok      ),
    // DIP switches
    .service     ( service      ),
    .dip_pause   ( dip_pause    ),
    .dipsw_a     ( dipsw_a      ),
    .dipsw_b     ( dipsw_b      )
);
`else
    assign main_cs  = 0;
    assign main_rnw = 1;
    assign main_addr= 0;
    assign cpu_dout = 0;
    assign char_cs  = 0;
    assign scr_cs   = 0;
    assign pal_cs   = 0;
    assign flip     = 0;
    assign cpu_AB   = 0;
`endif

jtrumble_video #(
    .CHARW  ( CHARW     ),
    .SCRW   ( SCRW      ),
    .OBJW   ( OBJW      )
)
u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .cpu_AB     ( cpu_AB        ),
    .V          ( vdump         ),
    .RnW        ( main_rnw      ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // Palette
    .pal_cs     ( pal_cs        ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scr_dout   ( scr_dout      ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    .scr_ok     ( scr_ok        ),
    // OBJ
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .dma_addr   ( obj_AB        ),
    .dma_data   ( obj_din       ),
    // PROMs
    .prog_addr  ( prog_addr[7:0]),
    .prom_prior_we(prom_prior_we),
    .prom_din   ( prog_data[3:0]),
    // Sync
    .vmid       ( vmid          ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

`ifndef NOSOUND
jtgng_sound #(
    .LAYOUT (10 ),
    .PSG_ATT( 1 )   // Fx is very loud in this game
) u_fmcpu (
    .rst        (  rst24        ),
    .clk        (  clk24        ),
    .cen3       (  cen24_4      ),
    .cen1p5     (  cen24_2      ), // unused
    .sres_b     (  sres_b       ),
    .snd_latch  (  snd_latch    ),
    .snd2_latch (               ),
    .snd_int    (  1'b1         ), // unused
    .enable_psg (  enable_psg   ),
    .enable_fm  (  enable_fm    ),
    .psg_level  (  {loud,1'b0}  ),
    .rom_addr   (  snd_addr     ),
    .rom_cs     (  snd_cs       ),
    .rom_data   (  snd_data     ),
    .rom_ok     (  snd_ok       ),
    .ym_snd     (  snd          ),
    .sample     (  sample       ),
    .peak       (  game_led     ),
    .debug_bus  ( debug_bus     ),
    .debug_view (               )
);
`else
    assign snd_addr   = 0;
    assign snd_cs     = 0;
    assign snd        = 0;
    assign sample     = 0;
    assign game_led   = 0;
//    assign debug_view = 0;
`endif

jtrumble_sdram #(
    .MAINW  ( MAINW ),
    .RAMW   ( RAMW  ),
    .CHARW  ( CHARW ),
    .SCRW   ( SCRW  ),
    .OBJW   ( OBJW  )
) u_sdram(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .LVBL       ( LVBL      ),
    .loud       ( loud      ),

    // Main CPU
    .main_cs    ( main_cs   ),
    .main_addr  ( main_addr ),
    .main_data  ( main_data ),

    .main_ok    ( main_ok   ),
    .main_dout  ( cpu_dout  ),

    // Sound CPU
    .snd_addr   ( snd_addr  ),
    .snd_cs     ( snd_cs    ),
    .snd_data   ( snd_data  ),
    .snd_ok     ( snd_ok    ),

    // Char interface
    .char_ok    ( char_ok   ),
    .char_addr  ( char_addr ), // 9 addr + 3 vertical + 2 horizontal = 14 bits
    .char_data  ( char_data ),

    // Scroll 1
    .scr1_ok    ( scr_ok    ),
    .scr1_addr  ( scr_addr  ),
    .scr1_data  ( scr_data  ),

    // Sprite interface
    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),

    // Bank 0: allows R/W
    .ba0_addr   ( ba0_addr  ),
    .ba1_addr   ( ba1_addr  ),
    .ba2_addr   ( ba2_addr  ),
    .ba3_addr   ( ba3_addr  ),
    .ba_rd      ( ba_rd     ),
    .ba_wr      ( ba_wr[0]  ),
    .ba_ack     ( ba_ack    ),
    .ba_dst     ( ba_dst    ),
    .ba_rdy     ( ba_rdy    ),
    .ba0_din    ( ba0_din   ),
    .ba0_din_m  ( ba0_dsn   ),

    .data_read  ( data_read ),

    // ROM load
    .ioctl_rom  ( ioctl_rom  ),
    .dwnld_busy (dwnld_busy  ),

    // PROM
    .prom_banks ( prom_bank  ),
    .prom_prior_we(prom_prior_we),

    .ioctl_addr ( ioctl_addr ),
    .ioctl_dout ( ioctl_dout ),
    .ioctl_wr   ( ioctl_wr   ),
    .prog_addr  ( prog_addr  ),
    .prog_data  ( prog_data  ),
    .prog_mask  ( prog_mask  ),
    .prog_ba    ( prog_ba    ),
    .prog_we    ( prog_we    ),
    .prog_rd    ( prog_rd    ),
    .prog_ack   ( prog_ack   ),
    .prog_dst   ( prog_dst   ),
    .prog_rdy   ( prog_rdy   )
);

endmodule
