/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-9-2026 */

module jtskykid_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:0] fave;
wire [ 1:0] busy;
reg  [ 7:0] dbg_mux;
wire [ 7:0] st_main, c30_dout, st_video, pri;
wire [ 8:0] scrx;
wire [ 7:0] scry;
wire        cen_E, cen_Q, cen_mcu, flip, srst,
            mc30_cs, mcu_seln, cpu_rnw, rot180;
reg         lvbl_ps;

assign debug_view = dbg_mux;
assign dip_flip   = flip;

always @(posedge clk) lvbl_ps <= LVBL & dip_pause;

always @* begin
    case( debug_bus[7:6] )
        0: dbg_mux = st_video;
        2: dbg_mux = st_main;
        3: dbg_mux = debug_bus[0] ? fave[7:0] : fave[15:8];
        default: dbg_mux = 0;
    endcase
end

jtskykid_header u_header(
    .clk        ( clk       ),
    .header     ( header    ),
    .prog_we    ( prog_we   ),
    .prog_addr  ( prog_addr[2:0] ),
    .prog_data  ( prog_data[7:0] ),
    .rot180     ( rot180    )
);

jtthundr_cenloop u_cen(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .busy       ( busy      ),

    .cen_main   ( cen_E     ),
    .cen_sub    ( cen_Q     ),
    .cen_mcu    ( cen_mcu   ),
    .mcu_seln   ( mcu_seln  ),

    .fave       ( fave      ),
    .fworst     (           )
);

jtskykid_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_E      ( cen_E     ),
    .cen_Q      ( cen_Q     ),
    .srst       ( srst      ),

    .lvbl       ( lvbl_ps   ),
    .scrx       ( scrx      ),
    .scry       ( scry      ),
    .pri        ( pri       ),
    .flip       ( flip      ),

    .cpu_dout   ( cpu_dout  ),
    .cpu_addr   ( cpu_addr  ),
    .rnw        ( cpu_rnw   ),
    // ROM
    .rom_cs     ( main_cs   ),
    .rom_ok     ( main_ok   ),
    .rom_addr   ( main_addr ),
    .rom_data   ( main_data ),

    .bus_busy   ( busy[0]   ),

    // VRAM
    .vram0_dout ( tx_dout   ),
    .vram1_dout ( bg_dout   ),
    .oram_dout  ( osh_dout  ),
    .vram0_we   ( tx_we     ),
    .vram1_we   ( bg_we     ),
    .oram_we    ( osh_we    ),

    // CUS30
    .c30_dout   ( c30_dout  ),
    .c30_cs     ( mc30_cs   ),

    .ioctl_din  ( ioctl_din ),
    .ioctl_addr ( ioctl_addr[1:0]),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_main   )
);

jtskykid_sound u_sound(
    .rst        ( srst      ),
    .clk        ( clk       ),
    .cen_mcu    ( cen_mcu   ),
    .cen_c30    ( cen_c30   ),

    .lvbl       ( lvbl_ps   ),

    .dipsw      (dipsw[19:0]),
    .joystick1  (joystick1[5:0]),
    .joystick2  (joystick2[5:0]),
    .cab_1p     (cab_1p[1:0]),
    .coin       ( coin[1:0] ),
    .service    ( service   ),

    // main CPU connection to CUS30
    .mcu_seln   ( mcu_seln  ),
    .c30_dout   ( c30_dout  ),
    .mc30_cs    ( mc30_cs   ),
    .mrnw       ( cpu_rnw   ),
    .maddr      (cpu_addr[9:0]),
    .mdout      ( cpu_dout  ),

    .ram_addr   (sndram_addr),
    .ram_dout   (sndram_dout),
    .ram_we     (sndram_we  ),
    .ram_din    (sndram_din ),

    .embd_addr  ( mcu_addr  ),
    .embd_data  ( mcu_data  ),

    .rom_cs     (mcusub_cs  ),
    .rom_ok     (mcusub_ok  ),
    .rom_addr   (mcusub_addr),
    .rom_data   (mcusub_data),
    .bus_busy   ( busy[1]   ),

    .cus30_l    ( cus30_l   ),
    .cus30_r    ( cus30_r   ),
    .debug_bus  ( debug_bus )
);

jtskykid_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .flip       ( flip      ),
    .rot        ( rot180    ),
    .scrx       ( scrx      ),
    .scry       ( scry      ),
    .pri        ( pri       ),

    .lvbl       ( LVBL      ),
    .lhbl       ( LHBL      ),
    .hs         ( HS        ),
    .vs         ( VS        ),

    // Objects
    .oram_addr  ( oram_addr ),
    .oram_dout  ( oram_dout ),

    // Tile map RAM
    .vram0_addr ( vram0_addr),
    .vram1_addr ( vram1_addr),
    .vram0_dout ( vram0_dout),
    .vram1_dout ( vram1_dout),

    // ROMs
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),
    .obj_ok     ( obj_ok    ),

    .scr0_cs    ( scr0_cs   ),
    .scr0_addr  ( scr0_addr ),
    .scr0_data  ( scr0_data ),
    .scr0_ok    ( scr0_ok   ),

    .scr1_cs    ( scr1_cs   ),
    .scr1_addr  ( scr1_addr ),
    .scr1_data  ( scr1_data ),
    .scr1_ok    ( scr1_ok   ),

    // Palette PROMs
    .objpal_addr ( objpal_addr  ),
    .objpal_data ( objpal_data  ),
    .scrpal_addr ( scrpal_addr  ),
    .scrpal_data ( scrpal_data  ),

    .rgb_addr    ( rgb_addr     ),
    .r_data      ( rpal_data    ),
    .g_data      ( gpal_data    ),
    .b_data      ( bpal_data    ),
    .red         ( red          ),
    .green       ( green        ),
    .blue        ( blue         ),
    // Debug
    .gfx_en      ( gfx_en       ),
    .debug_bus   ( debug_bus    ),
    .st_dout     ( st_video     )
);

endmodule
