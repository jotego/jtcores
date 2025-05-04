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
    Date: 15-3-2025 */

module jtthundr_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:0] fave, maddr;
wire [ 1:0] busy, pcm_wraddr;
reg  [ 7:0] dbg_mux;
wire [ 7:0] backcolor, st_main, mdout, c30_dout, st_video;
wire [ 8:0] scr0x, scr0y, scr1x, scr1y;
wire        cen_main, cen_sub, cen_mcu, flip, mmr0_cs, mmr1_cs, brnw, tile_bank,
            mrnw, bsel, mc30_cs, mcu_seln, dmaon, ommr_cs, pcm_wr;
// Configuration through MRA header
wire        scr2bpp, sndext_en, nocpu2, mcualt, genpeitd, roishtar, wndrmomo;
reg         lvbl_ps;

assign debug_view = dbg_mux;
assign dip_flip   = flip;

assign flip = 0;

always @(posedge clk) lvbl_ps <= LVBL & dip_pause;

always @* begin
    case( debug_bus[7:6] )
        0: dbg_mux = st_video;
        // 1: dbg_mux = { 3'd0, mcu_halt, 3'd0, ~srst_n };
        2: dbg_mux = st_main;
        3: dbg_mux = debug_bus[0] ? fave[7:0] : fave[15:8]; // average CPU frequency (BCD format)
        default: dbg_mux = 0;
    endcase
end

jtthundr_header u_header(
    .clk        ( clk       ),
    .header     ( header    ),
    .prog_we    ( prog_we   ),

    .nocpu2     ( nocpu2    ),
    .scr2bpp    ( scr2bpp   ),
    .sndext_en  ( sndext_en ),
    .mcualt     ( mcualt    ),
    .genpeitd   ( genpeitd  ),
    .roishtar   ( roishtar  ),
    .wndrmomo   ( wndrmomo  ),
    .prog_addr  ( prog_addr[2:0] ),
    .prog_data  ( prog_data )
);

jtthundr_cenloop u_cen(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .busy       ( busy      ),

    .cen_main   ( cen_main  ),
    .cen_sub    ( cen_sub   ),
    .cen_mcu    ( cen_mcu   ),
    .mcu_seln   ( mcu_seln  ),

    .fave       ( fave      ),
    .fworst     (           )
);

jtthundr_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_main   ( cen_main  ),
    .cen_sub    ( cen_sub   ),
    .lvbl       ( lvbl_ps   ),
    .nocpu2     ( nocpu2    ),

    .dmaon      ( dmaon     ),
    .ommr_cs    ( ommr_cs   ),

    .backcolor  ( backcolor ),
    .tile_bank  ( tile_bank ),

    // ROM
    .mrom_cs    ( main_cs   ),
    .mrom_ok    ( main_ok   ),
    .mrom_addr  ( main_addr ),
    .mrom_data  ( main_data ),

    .srom_cs    ( snd_cs    ),
    .srom_ok    ( snd_ok    ),
    .srom_addr  ( snd_addr  ),
    .srom_data  ( snd_data  ),

    .ext_cs     ( ext_cs    ),
    .ext_ok     ( ext_ok    ),
    .ext_addr   ( ext_addr  ),
    .ext_data   ( ext_data  ),
    .sndext_en  ( sndext_en ),

    .bus_busy   ( busy[0]   ),

    // VRAM
    .baddr      ( baddr     ),
    .bdout      ( bdout     ),
    .scr0_dout  (vram02sh0_data ),
    .scr1_dout  (vram12sh1_data ),
    .oram_dout  (oram2osh_data ),
    .scr0_we    ( sh0_we    ),
    .scr1_we    ( sh1_we    ),
    .oram_we    ( osh_we    ),
    .brnw       ( brnw      ),

    .latch0_cs  ( mmr0_cs   ),
    .latch1_cs  ( mmr1_cs   ),

    // CUS30
    .bsel       ( bsel      ),
    .c30_dout   ( c30_dout  ),
    .mc30_cs    ( mc30_cs   ),
    .mrnw       ( mrnw      ),
    .maddr      ( maddr     ),
    .mdout      ( mdout     ),
    // PCM
    .pcm_wr     ( pcm_wr    ),
    .pcm_addr   ( pcm_wraddr),

    .debug_bus  ( debug_bus ),
    .st_dout    ( st_main   )
);

jtthundr_sound u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_mcu    ( cen_mcu   ),
    .cen_fm     ( cen_fm    ),
    .cen_fm2    ( cen_fm2   ),
    .cen_pcm    ( cen_pcm   ),
    .cen_c30    ( cen_c30   ),
    .pxl_cen    ( pxl_cen   ),

    .lvbl       ( lvbl_ps   ),
    .hopmappy   ( mcualt    ),
    .genpeitd   ( genpeitd  ),
    .roishtar   ( roishtar  ),
    .wndrmomo   ( wndrmomo  ),

    .dipsw      ( dipsw[15:0]),
    .joystick1  (joystick1[6:0]),
    .joystick2  (joystick2[6:0]),
    .cab_1p     ( cab_1p[1:0]),
    .coin       ( coin[1:0] ),
    .service    ( service   ),

    // sub 6809 connection to CUS30/PCM MCU
    .mcu_seln   ( mcu_seln  ),
    .c30_dout   ( c30_dout  ),
    .pcm_wr     ( pcm_wr    ),
    .pcm_waddr  ( pcm_wraddr),
    .mc30_cs    ( mc30_cs   ),
    .mrnw       ( mrnw      ),
    .maddr      ( maddr[9:0]),
    .mdout      ( mdout     ),

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

    // PCM samples
    .pcm0_addr  ( pcm0_addr ),
    .pcm0_data  ( pcm0_data ),
    .pcm0_cs    ( pcm0_cs   ),
    .pcm0_ok    ( pcm0_ok   ),

    .pcm1_addr  ( pcm1_addr ),
    .pcm1_data  ( pcm1_data ),
    .pcm1_cs    ( pcm1_cs   ),
    .pcm1_ok    ( pcm1_ok   ),

    .fm_l       ( fm_l      ),
    .fm_r       ( fm_r      ),
    .pcm0       ( pcm0      ),
    .pcm1       ( pcm1      ),
    .cus30_l    ( cus30_l   ),
    .cus30_r    ( cus30_r   ),
    .debug_bus  ( debug_bus )
);

jtthundr_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .flip       ( flip      ),
    .backcolor  ( backcolor ),
    .bank       ( tile_bank ),

    .dmaon      ( dmaon     ),
    .ommr_cs    ( ommr_cs   ),

    .lvbl       ( LVBL      ),
    .lhbl       ( LHBL      ),
    .hs         ( HS        ),
    .vs         ( VS        ),

    .mmr0_cs    ( mmr0_cs   ),
    .mmr1_cs    ( mmr1_cs   ),
    .cpu_rnw    ( brnw      ),
    .cpu_dout   ( bdout     ),
    .cpu_addr   ( baddr     ),

    // Objects
    .oram_addr  ( oram_addr ),
    .oram_dout  ( oram_dout ),
    .oram_din   ( oram_din  ),
    .oram_we    ( oram_we   ),

    // Tile ROM decoder PROM
    .vram0_addr ( vram0_addr),
    .vram1_addr ( vram1_addr),
    .vram0_dout ( vram0_dout),
    .vram1_dout ( vram1_dout),
    .dec0_addr  ( dec0_addr ),
    .dec1_addr  ( dec1_addr ),
    .dec0_data  ( dec0_data ),
    .dec1_data  ( dec1_data ),

    // ROMs
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),
    .obj_ok     ( obj_ok    ),

    .scr0a_cs   ( scr0a_cs  ),
    .scr0a_addr ( scr0a_addr),
    .scr0a_data ( scr0a_data),
    .scr0a_ok   ( scr0a_ok  ),

    .scr0b_cs   ( scr0b_cs  ),
    .scr0b_addr ( scr0b_addr),
    .scr0b_data ( scr0b_data),
    .scr0b_ok   ( scr0b_ok  ),

    .scr1a_cs   ( scr1a_cs  ),
    .scr1a_addr ( scr1a_addr),
    .scr1a_data ( scr1a_data),
    .scr1a_ok   ( scr1a_ok  ),

    .scr1b_cs   ( scr1b_cs  ),
    .scr1b_addr ( scr1b_addr),
    .scr1b_data ( scr1b_data),
    .scr1b_ok   ( scr1b_ok  ),

    // Palette PROMs
    .objpal_addr(objpal_addr),
    .objpal_data(objpal_data),

    .scrpal_addr(scrpal_addr),
    .scrpal_data(scrpal_data),

    .rgb_addr   ( rgb_addr  ),
    .rg_data    ( rgpal_data),
    .b_data     ( bpal_data[3:0] ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    // Debug
    .ioctl_din  ( ioctl_din ),
    .ioctl_addr ( ioctl_addr[4:0] ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_video  )
);

endmodule
