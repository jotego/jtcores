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
    Date: 2-4-2022 */

module jtrastan_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:0] oram_dout, pal_dout;
wire [ 1:0] main_dsn;
wire        sub_cs, obj_cs, ram_cs, vram_cs, main_rnw;
wire        scr_cs, pal_cs, sdakn, odakn;
wire [ 2:0] obj_pal;

wire        flip;
wire        sn_rd, sn_we, snd_rstn, mintn;
wire [ 3:0] main2snd, sn_dout;
wire        opwolf, cchip;
// Light-gun offsets: signed 8-bit values from header bytes 1/2, sign-extended.
wire [ 7:0] gun_xoff8, gun_yoff8;
wire [ 8:0] gun_xoffs = {gun_xoff8[7], gun_xoff8};
wire [ 8:0] gun_yoffs = {gun_yoff8[7], gun_yoff8};

// C-chip (Operation Wolf good sets)
wire        cchip_cs;
wire [ 7:0] cchip_dout;

assign dip_flip = flip;
assign ram_addr = ram_cs ? (opwolf ? {3'd0, main_addr[14:1]} : {4'd0, main_addr[13:1]}) :
                           {2'b10, main_addr[15:1]};
assign ram_we   = xram_cs & ~main_rnw;
assign xram_cs  = ram_cs | vram_cs;
assign ram_dsn  = main_dsn;
assign main2snd = opwolf ? main_dout[11:8] : main_dout[3:0];

// Header fields (byte0 bit0=Op Wolf hardware, bit1=C-chip; byte1/2 = signed
// gun X/Y offsets) — latched by the generated jtrastan_header (see mame2mra.toml).
jtrastan_header u_header(
    .clk        ( clk            ),
    .header     ( header         ),
    .prog_we    ( prog_we        ),
    .opwolf     ( opwolf         ),
    .cchip      ( cchip          ),
    .gun_xoff8  ( gun_xoff8      ),
    .gun_yoff8  ( gun_yoff8      ),
    .prog_addr  ( prog_addr[2:0] ),
    .prog_data  ( prog_data      )
);

jtrastan_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ), // 48 MHz
    .LVBL       ( LVBL      ),
    .opwolf     ( opwolf    ),
    .cchip      ( cchip     ),
    .cchip_cs   ( cchip_cs  ),
    .cchip_dout ( cchip_dout),
    .gun_xoffs  ( gun_xoffs ),
    .gun_yoffs  ( gun_yoffs ),

    .main_addr  ( main_addr ),
    .main_dout  ( main_dout ),
    .main_dsn   ( main_dsn  ),
    .main_rnw   ( main_rnw  ),
    .rom_cs     ( main_cs   ),
    .ram_cs     ( ram_cs    ),
    .vram_cs    ( vram_cs   ),
    .obj_cs     ( obj_cs    ),
    .pal_cs     ( pal_cs    ),
    .scr_cs     ( scr_cs    ),

    .obj_pal    ( obj_pal   ),
    .oram_dout  ( oram_dout ),
    .pal_dout   ( pal_dout  ),
    .ram_dout   ( ram_data  ),
    .ram_ok     ( ram_ok    ),
    .rom_data   ( main_data ),
    .rom_ok     ( main_ok   ),

    .odakn      ( odakn     ),
    .sdakn      ( sdakn     ),

    // Sound interface
    .sn_dout    ( sn_dout   ),
    .sn_rd      ( sn_rd     ),
    .sn_we      ( sn_we     ),

    // test board interface
    .sub_cs     ( sub_cs    ),
    .snd_rstn   ( snd_rstn  ),
    .mintn      ( mintn     ),

    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .gun_x      ( gun_1p_x  ),
    .gun_y      ( gun_1p_y  ),
    .cab_1p     (cab_1p[1:0]),
    .coin       ( coin[1:0] ),
    .tilt       ( tilt      ),
    .service    ( service   ),

    .dip_test   ( dip_test  ),
    .dip_pause  ( dip_pause ),
    .dipsw_a    (dipsw[ 7:0]),
    .dipsw_b    (dipsw[15:8])
);

jtrastan_snd u_sound(
    .rst        ( rst24         ),
    .clk        ( clk24         ), // 24 MHz
    .cen4       ( cen4          ),
    .cen2       ( cen2          ),
    .pcm_cen    ( pcm_cen       ),
    .opwolf     ( opwolf        ),

    // From main CPU
    .rst48      ( rst           ),
    .clk48      ( clk           ),
    .main_addr  (main_addr[1]   ),
    .main_dout  ( main2snd      ),
    .main_din   ( sn_dout       ),
    .main_rnw   ( main_rnw      ),
    .sn_we      ( sn_we         ),
    .sn_rd      ( sn_rd         ),

    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_ok     ( snd_ok        ),
    .rom_data   ( snd_data      ),

    .pcm0_addr  ( pcm0_addr     ),
    .pcm0_cs    ( pcm0_cs       ),
    .pcm0_ok    ( pcm0_ok       ),
    .pcm0_data  ( pcm0_data     ),
    .pcm1_addr  ( pcm1_addr     ),
    .pcm1_cs    ( pcm1_cs       ),
    .pcm1_ok    ( pcm1_ok       ),
    .pcm1_data  ( pcm1_data     ),

    .fm_l       ( fm_l          ),
    .fm_r       ( fm_r          ),
    .pcm0       ( pcm0          ),
    .pcm1       ( pcm1          )
);

jtrastan_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .opwolf     ( opwolf    ),

    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .flip       ( flip      ),
    .obj_pal    ( obj_pal   ),

    .main_addr  ( main_addr ),
    .main_dout  ( main_dout ),
    .oram_dout  ( oram_dout ),
    .pal_dout   ( pal_dout  ),
    .main_dsn   ( main_dsn  ),
    .main_rnw   ( main_rnw  ),
    .scr_cs     ( scr_cs    ),
    .pal_cs     ( pal_cs    ),
    .obj_cs     ( obj_cs    ),
    .sdakn      ( sdakn     ),
    .odakn      ( odakn     ),

    .ram0_addr  ( scr0ram_addr ),
    .ram0_data  ( scr0ram_data ),
    .ram0_ok    ( scr0ram_ok   ),
    .ram0_cs    ( scr0ram_cs   ),

    .rom0_addr  ( scr0rom_addr ),
    .rom0_data  ( scr0rom_data ),
    .rom0_cs    ( scr0rom_cs   ),
    .rom0_ok    ( scr0rom_ok   ),

    .ram1_addr  ( scr1ram_addr ),
    .ram1_data  ( scr1ram_data ),
    .ram1_ok    ( scr1ram_ok   ),
    .ram1_cs    ( scr1ram_cs   ),

    .rom1_addr  ( scr1rom_addr ),
    .rom1_data  ( scr1rom_data ),
    .rom1_cs    ( scr1rom_cs   ),
    .rom1_ok    ( scr1rom_ok   ),

    .orom_addr  ( orom_addr    ),
    .orom_data  ( orom_data    ),
    .orom_cs    ( orom_cs      ),
    .orom_ok    ( orom_ok      ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    // Debug
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_addr ( ioctl_addr[10:0]),
    .ioctl_din  ( ioctl_din ),
    .debug_view ( debug_view)
);

jttc0030cmd u_cchip(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .cen        ( cchip_cen         ),
    .cs         ( cchip_cs          ),
    .addr       ( main_addr[11:1]   ),
    .din        ( main_dout[7:0]    ),
    .dout       ( cchip_dout        ),
    .rnw        ( main_rnw | main_dsn[0] ),
    .dtack_n    (                   ),
    .int1       ( ~LVBL             ),
    .nmi_n      ( 1'b1              ),
    .pa_in      ( 8'h00             ),
    .pb_in      ( {6'h3f, ~coin[1:0]}),
    .pc_in      ( {3'b111, cab_1p[0], tilt, service,
                   joystick1[5], joystick1[4]} ),
    .pa_out     (                   ),
    .pb_out     (                   ),
    .pc_out     (                   ),
    .an         ( 8'h00             ),
    .mrom_addr  ( cchip_mask_addr   ),
    .mrom_data  ( cchip_mask_data   ),
    .eprom_addr ( cchip_eprom_addr  ),
    .eprom_data ( cchip_eprom_data  ),
    // debug (unused)
    .dbg_pc     (                   ),
    .dbg_fetch  (                   )
);

endmodule
