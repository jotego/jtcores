/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 5-4-2021 */

module jtrumble_game(
    input           rst,
    input           clk,
    input           rst24,
    input           clk24,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL_dly,
    output          LVBL_dly,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 5:0]  joystick1,
    input   [ 5:0]  joystick2,

    // SDRAM interface
    input           downloading,
    output          dwnld_busy,

    // Bank 0: allows R/W
    output   [21:0] ba0_addr,
    output   [21:0] ba1_addr,
    output   [21:0] ba2_addr,
    output   [21:0] ba3_addr,
    output   [15:0] ba0_din,
    output   [ 1:0] ba0_din_m,  // write mask
    output   [ 3:0] ba_rd,
    output          ba_wr,
    input    [ 3:0] ba_ack,
    input    [ 3:0] ba_dst,
    input    [ 3:0] ba_dok,
    input    [ 3:0] ba_rdy,

    input   [15:0]  data_read,
    // ROM LOAD
    input   [24:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [15:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output  [ 1:0]  prog_ba,
    output          prog_we,
    output          prog_rd,
    input           prog_ack,
    input           prog_dst,
    input           prog_dok,
    input           prog_rdy,

    // DIP switches
    input   [31:0]  status,
    input   [31:0]  dipsw,
    input           service,
    input           dip_pause,
    output          dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  signed [15:0] snd,
    output          sample,
    output          game_led,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [3:0]   gfx_en
);

localparam MAINW=18, RAMW=13, CHARW=13, SCRW=17, OBJW=17;

// ROM data
wire [15:0] char_data;
wire [15:0] scr_data;
wire [15:0] obj_data, obj_pre;
wire [ 7:0] main_data, dma_data, ram_data;
wire [ 7:0] snd_data, snd_latch;
wire [ 7:0] cpu_dout, scr_dout, char_dout;
// ROM address
wire [17:0] main_addr;
wire [12:0] ram_addr;
wire [14:0] snd_addr;
wire [ 8:0] dma_addr;
wire [CHARW-1:0] char_addr;
wire [SCRW-1:0] scr_addr;
wire [OBJW-1:0] obj_addr;
wire [ 7:0] dipsw_a, dipsw_b;
wire        cenfm, cpu_cen;

wire [ 9:0] scr_hpos, scr_vpos;
wire [ 8:0] vdump;
wire        scr_busy, char_busy;

wire        main_rnw;
wire        main_ok, snd_ok, char_ok, scr_ok,
            obj_ok, dma_ok, ram_ok;
wire        main_cs, snd_cs, obj_cs, dma_cs, ram_cs,
            pal_cs, char_cs, scr_cs;

wire [ 1:0] prom_bank;
wire        prom_prior_we;

wire        vmid, cen24_8, cen24_4, cen24_2;
wire        sres_b, flip;
wire        LVBL, LHBL;
wire        bus_ack, bus_req, blcnten;

assign { dipsw_b, dipsw_a } = dipsw[15:0];
assign dip_flip = ~flip;
assign obj_cs   = 1;

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
    .char_busy  ( char_busy     ),
    // scroll
    .scr_dout   ( scr_dout      ),
    .scr_cs     ( scr_cs        ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    // cabinet I/O
    .start_button( start_button ),
    .coin_input  ( coin_input   ),
    .joystick1   ( joystick1    ),
    .joystick2   ( joystick2    ),
    // BUS sharing
    .bus_ack     ( bus_ack      ),
    .bus_req     ( bus_req      ),
    .RnW         ( main_rnw     ),
    // ROM access
    .rom_cs      ( main_cs      ),
    .rom_addr    ( main_addr    ),
    .rom_data    ( main_data    ),
    .rom_ok      ( main_ok      ),
    // RAM access
    .ram_cs      ( ram_cs       ),
    .ram_addr    ( ram_addr     ),
    .ram_data    ( ram_data     ),
    .ram_ok      ( ram_ok       ),
    // DIP switches
    .service     ( service      ),
    .dip_pause   ( dip_pause    ),
    .dipsw_a     ( dipsw_a      ),
    .dipsw_b     ( dipsw_b      )
);
`else
assign main_cs  = 0;
assign ram_cs   = 0;
assign main_rnw = 1;
assign cpu_dout = 0;
assign char_cs  = 0;
assign scr_cs   = 0;
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
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( ram_addr[12:0]),
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
    .dma_addr   ( dma_addr      ),
    .dma_data   ( dma_data      ),
    .dma_ok     ( dma_ok        ),
    .dma_cs     ( dma_cs        ),

    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    // PROMs
    .prog_addr  ( prog_addr[7:0]),
    .prom_prior_we(prom_prior_we),
    .prom_din   ( prog_data[3:0]),
    // Sync
    .vmid       ( vmid          ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .LHBL_dly   ( LHBL_dly      ),
    .LVBL_dly   ( LVBL_dly      ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .gfx_en     ( gfx_en        ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

`ifndef NOSOUND
jtgng_sound #(
    .LAYOUT (10 ),
    .PSG_ATT( 2 )   // Fx is very loud in this game
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
    .psg_level  (  dip_fxlevel  ),
    .rom_addr   (  snd_addr     ),
    .rom_cs     (  snd_cs       ),
    .rom_data   (  snd_data     ),
    .rom_ok     (  snd_ok       ),
    .ym_snd     (  snd          ),
    .sample     (  sample       ),
    .peak       (  game_led     )
);
`else
    assign snd_cs=0;
    assign sample=0;
    assign snd = 0;
    assign game_led=0;
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

    // Main CPU
    .main_cs    ( main_cs   ),
    .ram_cs     ( ram_cs    ),

    .main_addr  ( main_addr ),
    .ram_addr   ( ram_addr  ),
    .main_data  ( main_data ),
    .ram_data   ( ram_data  ),

    .main_ok    ( main_ok   ),
    .ram_ok     ( ram_ok    ),

    .main_dout  ( cpu_dout  ),
    .main_rnw   ( main_rnw  ),

    // DMA
    .dma_cs     ( dma_cs    ),
    .dma_addr   ( dma_addr  ),
    .dma_ok     ( dma_ok    ),
    .dma_data   ( dma_data  ),

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
    .ba_wr      ( ba_wr     ),
    .ba_ack     ( ba_ack    ),
    .ba_dst     ( ba_dst    ),
    .ba_rdy     ( ba_rdy    ),
    .ba0_din    ( ba0_din   ),
    .ba0_din_m  ( ba0_din_m ),

    .data_read  ( data_read ),

    // ROM load
    .downloading(downloading ),
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