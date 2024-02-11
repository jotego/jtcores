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
    Date: 21-9-2023 */

module jtshouse_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [21:0] baddr;
wire [15:0] fave;
wire        brnw, srnw, mcu_rnw, srst_n, firqn,
            btri_cs, stri_cs, mcutri_cs, vram_cs,
            key_cs, bc30_cs, pal_cs, pcm_busy, scfg_cs;
wire [ 7:0] bdout, sndcpu_dout, c30_dout,
            key_dout, pal_dout, scfg_dout,
            tri_snd, tri_mcu, tri_dout,
            st_video, st_main;
wire [ 8:0] hdump;
wire [ 2:0] busy;
reg  [ 7:0] dbg_mux;
wire signed [10:0] pcm_snd;
wire        prc_snd, snd_sel,
            cen_main, cen_sub,  cen_snd,  cen_mcu, cen_sndq;
wire        obus_cs, ram_cs, dma_we, mcu_halt;

// bit 16 of ROM T10 in sch. is inverted. T10 is also shorter (128kB only)
// limiting to 128kB ROMs for now to allow address mirroring on Splatter
// To do: use a header byte to config this? duplicate content in the MRA?
assign main_addr = { baddr[21:19], 2'd0, &baddr[21:19] ? { ~baddr[16],baddr[15:0]} : baddr[16:0] };
assign sub_addr  = main_addr;
assign debug_view= dbg_mux;

assign ram_addr  = baddr[14:0];
assign ram_din   = bdout;
// assign ram_dsn   = 2'b11; // this is ignored by the logic
assign ram_we    =  ram_cs & ~brnw;
assign vram_addr = baddr[14:1];
assign vram_we   = {2{vram_cs & ~brnw}} & {baddr[0], ~baddr[0]};
assign oram_we   = {2{dma_we}};

assign sndram_addr = snd_addr[12:0];
assign sndram_din  = sndcpu_dout;
assign bdout16 = {2{bdout}};

// To do:
assign dip_flip = 0;

always @* begin
    case( debug_bus[7:6] )
        0: dbg_mux = { 3'd0, mcu_halt, 3'd0, ~srst_n };
        1: dbg_mux = st_video;
        2: dbg_mux = st_main;
        3: dbg_mux = debug_bus[0] ? fave[7:0] : fave[15:8]; // average CPU frequency (BCD format)
        default: dbg_mux = 0;
    endcase
end

/* verilator tracing_on */
jtshouse_cenloop u_cen(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .busy       ( busy      ),

    .cen_main   ( cen_main  ),
    .cen_sub    ( cen_sub   ),
    .cen_snd    ( cen_snd   ),
    .cen_sndq   ( cen_sndq  ),
    .cen_mcu    ( cen_mcu   ),
    .snd_sel    ( snd_sel   ),

    .fave       ( fave      ),
    .fworst     (           )
);
/* verilator tracing_on */
jtshouse_key u_key(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .cs         ( key_cs    ),
    .rnw        ( brnw      ),
    .addr       ( baddr[7:0]),
    .din        ( bdout     ),
    .dout       ( key_dout  ),

    .prog_en    ( header    ),
    .prog_wr    ( prog_we   ),
    .prog_addr  ( prog_addr[2:0] ),
    .prog_data  ( prog_data )
);
/* verilator tracing_on */
jtshouse_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_main   ( cen_main  ),
    .cen_sub    ( cen_sub   ),

    .lvbl       ( LVBL & dip_pause ),
    .firqn      ( firqn     ),     // input that will trigger both FIRQ outputs

    .baddr      ( baddr     ),  // shared by both CPUs
    .bdout      ( bdout     ),
    .brnw       ( brnw      ),

    .bc30_cs    ( bc30_cs   ),
    .tri_cs     ( btri_cs   ),
    .key_cs     ( key_cs    ),
    .pal_cs     ( pal_cs    ),
    .scfg_cs    ( scfg_cs   ),
    .scfg_dout  ( scfg_dout ),

    .tri_dout   ( tri_dout  ),
    .key_dout   ( key_dout  ),
    .pal_dout   ( pal_dout  ),
    .c30_dout   ( c30_dout  ),

    // Video RAM
    .oram_cs    ( obus_cs   ),
    .obus_we    ( obus_we   ),
    .obus_addr  ( obus_addr ),
    .obus_dout  ( obus_dout ),
    .vram_cs    ( vram_cs   ),
    .vram_dout  ( vram_dout ),

    .srst_n     ( srst_n    ),

    .mrom_cs    ( main_cs   ),
    .srom_cs    ( sub_cs    ),
    .ram_cs     ( ram_cs    ),
    .mrom_ok    ( main_ok   ),
    .srom_ok    ( sub_ok    ),
    // .ram_ok     ( ram_ok    ),
    .ram_ok     ( 1'b1      ),
    .mrom_data  ( main_data ),
    .srom_data  ( sub_data  ),
    .ram_dout   ( ram_dout  ),
    .bus_busy   ( busy[0]   ),

    .debug_bus  ( debug_bus ),
    .st_dout    ( st_main   )
);
/* verilator tracing_on */
jtshouse_mcu u_mcu(
    .game_rst   ( rst       ),
    .rstn       ( srst_n    ),
    .clk        ( clk       ),
    .cen        ( cen_mcu   ), // is 2 the best one?

    .lvbl       ( LVBL      ),
    .hdump      ( hdump     ),

    .rnw        ( mcu_rnw   ),
    .mcu_dout   ( mcu_dout  ),
    .ram_cs     ( mcutri_cs ),
    .ram_dout   ( tri_mcu   ),
    .halted     ( mcu_halt  ),
    // cabinet I/O
    .cab_1p     ( cab_1p    ),
    .coin       ( coin      ),
    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .dipsw      ( dipsw[7:0]),
    .service    ( service   ),
    .dip_test   ( dip_test  ),

    // PROM programming
    .prog_addr  (prog_addr[11:0]),
    .prog_data  ( prog_data ),
    .prog_we    ( prom_we   ),

    // EEROM
    .mcu_addr   ( eerom_addr),
    .eerom_dout ( eerom_dout),
    .eerom_we   ( eerom_we  ),

    // "Voice" ROM
    .pcm_addr   ( pcm_addr  ),
    .pcm_data   ( pcm_data  ),
    .pcm_cs     ( pcm_cs    ),
    .pcm_ok     ( pcm_ok    ),
    .bus_busy   ( busy[1]   ),

    .snd        ( pcm_snd   ),
    .debug_bus  ( debug_bus )
);
/* verilator tracing_on */
jtshouse_sound u_sound(
    .srst_n     ( srst_n    ),
    .clk        ( clk       ),
    .cen_E      ( cen_snd   ),
    .cen_Q      ( cen_sndq  ),
    .cen_sub    ( cen_sub   ),
    .cen_fm     ( cen_fm    ),
    .cen_fm2    ( cen_fm2   ),
    .lvbl       ( LVBL      ),

    .bc30_cs    ( bc30_cs   ),
    .baddr      ( baddr[9:0]),
    .brnw       ( brnw      ),
    .bdout      ( bdout     ),
    .c30_dout   ( c30_dout  ),

    .tri_cs     ( stri_cs   ),
    .tri_dout   ( tri_snd   ),

    .rnw        ( srnw      ),
    .ram_we     ( sndram_we ),
    .ram_dout   (sndram_dout),
    .cpu_dout   (sndcpu_dout),

    .rom_cs     ( snd_cs    ),
    .rom_addr   ( snd_addr  ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),
    .bus_busy   ( busy[2]   ),

    .pcm_snd    ( pcm_snd   ),
    .left       ( snd_left  ),
    .right      ( snd_right ),
    .sample     ( sample    ),
    .peak       ( game_led  ),
    .debug_bus  ( debug_bus )
);
/* verilator tracing_off */
jtshouse_triram u_triram(
    .rst        ( rst       ),
    .srst_n     ( srst_n    ),
    .clk        ( clk       ),

    .snd_cen    ( cen_snd   ),
    .mcu_cen    ( cen_mcu   ),
    .snd_sel    ( snd_sel   ),

    .baddr      ( baddr[10:0]   ),
    .mcu_addr   ( eerom_addr    ),
    .saddr      (snd_addr[10:0] ),

    // CS to the tri RAM from each subsystem
    .bus_cs     ( btri_cs   ),
    .mcu_cs     ( mcutri_cs ),
    .snd_cs     ( stri_cs   ),

    .brnw       ( brnw      ),
    .mcu_rnw    ( mcu_rnw   ),
    .srnw       ( srnw      ),

    .bdout      ( bdout     ),
    .mcu_dout   ( mcu_dout  ),
    .sdout      (sndcpu_dout),

    .bdin       ( tri_dout  ),
    .mcu_din    ( tri_mcu   ),
    .snd_din    ( tri_snd   ),

    .debug_bus  ( debug_bus )
);
/* verilator tracing_off */
jtshouse_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .hdump      ( hdump     ),

    .lvbl       ( LVBL      ),
    .lhbl       ( LHBL      ),
    .hs         ( HS        ),
    .vs         ( VS        ),

    .raster_irqn( firqn     ),

    .pal_cs     ( pal_cs    ),
    .pal_dout   ( pal_dout  ),
    .scfg_cs    ( scfg_cs   ),
    .scfg_dout  ( scfg_dout ),
    .cpu_addr   (baddr[14:0]),
    .cpu_rnw    ( brnw      ),
    .cpu_dout   ( bdout     ),
    // Object RAM
    .obus_cs    ( obus_cs   ),
    .oram_addr  ( oram_addr ),
    .oram_dout  ( oram_dout ),
    .oram_din   ( oram_din  ),
    .oram_we    ( dma_we    ),
    // Palette RAM
    .pal_addr   ( pal_addr  ),
    .rgb_addr   ( rgb_addr  ),
    .rpal_we    ( rpal_we   ),
    .gpal_we    ( gpal_we   ),
    .bpal_we    ( bpal_we   ),
    .rpal_dout  ( rpal_dout ),
    .gpal_dout  ( gpal_dout ),
    .bpal_dout  ( bpal_dout ),
    // Tile map readout (BRAM)
    .tmap_addr  ( tmap_addr ),
    // .tmap_data  ( tmap_dout ),
    .tmap_data  ( {tmap_dout[7:0],tmap_dout[15:8]} ),
    // Scroll mask readout (SDRAM)
    .mask_cs    ( mask_cs   ),
    .mask_ok    ( mask_ok   ),
    .mask_addr  ( mask_addr ),
    .mask_data  ( mask_data ),
    // Scroll tile readout (SDRAM)
    .scr_cs     ( scr_cs    ),
    .scr_ok     ( scr_ok    ),
    .scr_addr   ( scr_addr  ),
    .scr_data   ( scr_data  ),
    // Object tile readout (SDRAM)
    .obj_data   ( obj_data  ),
    .obj_addr   ( obj_addr  ),
    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),
    // color mixer
    .red_dout   ( red_dout  ),
    .green_dout ( green_dout),
    .blue_dout  ( blue_dout ),

    // IOCTL dump
    .ioctl_addr (ioctl_addr[5:0]),
    .ioctl_din  ( ioctl_din ),

    .debug_bus  ( debug_bus ),
    .gfx_en     ( gfx_en    ),
    .st_dout    ( st_video  ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

endmodule
