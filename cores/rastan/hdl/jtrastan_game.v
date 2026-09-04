/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-4-2022 */

module jtrastan_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [ 1:0] main_dsn;
wire        sub_cs, obj_cs, ram_cs, vram_cs, main_rnw;
wire        scr_cs, pal_cs, sdakn, odakn;
wire [ 2:0] obj_pal;

wire        flip;
wire        sn_rd, sn_we, snd_rstn, mintn, main_cen;
wire [ 3:0] main2snd, sn_dout;
wire        rastan, opwolf, rbisland;  // one-hot game select, straight from header
wire        cchip;                     // C-chip present (Op Wolf good sets, Rainbow)
// Light-gun offsets: signed 8-bit values from header bytes 1/2, sign-extended.
wire [ 7:0] gun_xoff8, gun_yoff8;
wire [ 8:0] gun_xoffs = {gun_xoff8[7], gun_xoff8};
wire [ 8:0] gun_yoffs = {gun_yoff8[7], gun_yoff8};

// C-chip (Operation Wolf, Rainbow Islands)
wire        cchip_cs;
wire [ 7:0] cchip_dout;
wire        cchip_rnw;
wire [ 7:0] mmr_din;
wire [ 4:0] mmr_addr;
`ifndef RASTAN_SCRRAM_SDRAM
wire [15:0] vram_dout;
`endif
wire [15:0] mainram_dout;

assign dip_flip = flip;
assign ram_addr = ram_cs ? (opwolf ? {3'd0, main_addr[14:1]} : {4'd0, main_addr[13:1]}) :
                           {2'b10, main_addr[15:1]};
assign ram_we   = xram_cs & ~main_rnw;
assign xram_cs  = ram_cs | vram_cs;
assign ram_dsn  = main_dsn;
assign objram_we = ~main_dsn & {2{obj_cs & ~main_rnw}};
assign palram_we = ~main_dsn & {2{pal_cs & ~main_rnw}};
assign main2snd = opwolf ? main_dout[11:8] : main_dout[3:0];
assign sample   = 0;
assign cchip_rnw = main_rnw | main_dsn[0];
assign ioctl_din = ioctl_addr[5] ? {obj_pal,5'd0} : mmr_din;
assign mmr_addr = ioctl_addr[4:0];
`ifdef RASTAN_SCRRAM_SDRAM
assign mainram_dout = ram_data;
`else
assign vram_cpu_addr = main_addr[15:2];
assign vram_cpu_din  = {2{main_dout}};
assign vram_we       = !main_rnw && vram_cs ?
                       (main_addr[1] ? {~main_dsn,2'b00} : {2'b00,~main_dsn}) : 4'd0;
assign vram_dout     = main_addr[1] ? vram_cpu_dout[31:16] : vram_cpu_dout[15:0];
assign mainram_dout  = vram_cs ? vram_dout : ram_data;
`endif

jtrastan_header u_header(
    .clk        ( clk            ),
    .header     ( header         ),
    .prog_we    ( prog_we        ),
    .rastan     ( rastan         ),
    .opwolf     ( opwolf         ),
    .rbisland   ( rbisland       ),
    .cchip      ( cchip          ),
    .gun_xoff8  ( gun_xoff8      ),
    .gun_yoff8  ( gun_yoff8      ),
    .prog_addr  ( prog_addr[2:0] ),
    .prog_data  ( prog_data      )
);

jtrastan_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ), // 48 MHz
    .cpu_cen    ( main_cen  ),
    .LVBL       ( LVBL      ),
    .opwolf     ( opwolf    ),
    .rbisland   ( rbisland  ),
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
    .oram_dout  ( objram2main_data ),
    .pal_dout   ( palram_dout ),
    .ram_dout   ( mainram_dout ),
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
    .rst        ( rst           ),
    .clk        ( clk           ),
    .fm_cen     ( fm_cen        ),
    .pcm_cen    ( pcm_cen       ),
    .fir_cen    ( fir_cen       ),

    .opwolf     ( opwolf        ),
    .rbisland   ( rbisland      ),

    // From main CPU
    .main_cen   ( main_cen      ),
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

    .left       ( snd_left      ),
    .right      ( snd_right     ),
    .peak       (               ),
    .debug_bus  ( debug_bus     )
);
`ifdef SIMSCENE
/* verilator tracing_on */
`else
/* verilator tracing_off */
`endif
jtrastan_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .opwolf     ( opwolf    ),
    .rbisland   ( rbisland  ),

    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .flip       ( flip      ),
    .obj_pal    ( obj_pal   ),

    .main_addr  ( main_addr ),
    .main_dout  ( main_dout ),
    .main_dsn   ( main_dsn  ),
    .main_rnw   ( main_rnw  ),
    .scr_cs     ( scr_cs    ),
    .obj_cs     ( obj_cs    ),
    .sdakn      ( sdakn     ),
    .odakn      ( odakn     ),

    .ioctl_addr ( mmr_addr  ),
    .ioctl_din  ( mmr_din   ),

    .objram_addr( objram_addr ),
    .objram_dout( objram_dout ),
    .palram_addr( palram_addr ),
    .palram_video_data( palram_video_data ),
`ifdef RASTAN_SCRRAM_SDRAM
    .ram0_addr  ( scr0ram_addr  ),
    .ram0_data  ( scr0ram_data  ),
    .ram0_ok    ( scr0ram_ok    ),
    .ram0_cs    ( scr0ram_cs    ),
    .ram1_addr  ( scr1ram_addr  ),
    .ram1_data  ( scr1ram_data  ),
    .ram1_ok    ( scr1ram_ok    ),
    .ram1_cs    ( scr1ram_cs    ),
`else
    .ram_addr   ( vram_vid_addr ),
    .ram_data   ( scrram_dout   ),
`endif

    .rom0_addr  ( scr0rom_addr ),
    .rom0_data  ( scr0rom_data ),
    .rom0_cs    ( scr0rom_cs   ),
    .rom0_ok    ( scr0rom_ok   ),

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
    .debug_view ( debug_view)
);

jtrastan_cchip u_cchip(
    .rst             ( rst              ),
    .clk             ( clk              ),
    .cen             ( cchip_cen        ),
    .cs              ( cchip_cs         ),
    .addr            ( main_addr[11:1]  ),
    .din             ( main_dout[7:0]   ),
    .dout            ( cchip_dout       ),
    .rnw             ( cchip_rnw        ),
    .LVBL            ( LVBL             ),
    .rbisland        ( rbisland         ),
    .service         ( service          ),
    .cab_1p          ( cab_1p[1:0]      ),
    .coin            ( coin[1:0]        ),
    .tilt            ( tilt             ),
    .joystick1       ( joystick1        ),
    .cchip_mask_addr ( cchip_mask_addr  ),
    .cchip_mask_data ( cchip_mask_data  ),
    .cchip_eprom_addr( cchip_eprom_addr ),
    .cchip_eprom_data( cchip_eprom_data )
);

endmodule
