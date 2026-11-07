/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-7-2026 */

module jtpktgal_game(
    `include "jtframe_game_ports.inc"
);

wire [15:0] cpu_addr, snd_cpu_addr;
wire [ 7:0] snd_latch;
wire        snd_irq;
wire        deco222, char_orig, char_bootleg;
wire [ 7:0] bac06_din, bac06_dout, st_main, st_sound, ioctl_bac06;
wire [ 4:0] bac06_addr;
wire        bac06_cs, bac06_rnw;

assign debug_view = dip_pause ? st_sound : st_main;
assign dip_flip   = 1'b0;
assign main_addr  = cpu_addr;
assign snd_addr   = snd_cpu_addr;
`ifdef JTFRAME_IOCTL_RD
assign ioctl_din  = ioctl_bac06;
`endif
/* verilator tracing_off */
jtpktgal_header u_header(
    .clk          ( clk           ),
    .header       ( header        ),
    .prog_we      ( prog_we       ),
    .char_orig    ( char_orig     ),
    .char_bootleg ( char_bootleg  ),
    .deco222      ( deco222       ),
    .prog_addr    ( prog_addr[2:0] ),
    .prog_data    ( prog_data     )
);

jtpktgal_main u_main(
    .rst          ( rst            ),
    .clk          ( clk            ),
    .cen_cpu      ( cpu_cen        ),
    .rom_addr     ( cpu_addr       ),
    .rom_cs       ( main_cs        ),
    .rom_data     ( main_data      ),
    .rom_ok       ( main_ok        ),
    .coin         ( coin[1:0]      ),
    .cab_1p       ( cab_1p[1:0]    ),
    .joystick1    ( joystick1      ),
    .joystick2    ( joystick2      ),
    .dipsw        ( dipsw[7:0]     ),
    .dip_pause    ( dip_pause      ),
    .LVBL         ( LVBL           ),
    .pf_cpu_addr  ( pf_cpu_addr    ),
    .pf_cpu_din   ( pf_cpu_din     ),
    .pf_cpu_dout  ( pf_cpu_dout    ),
    .pf_we        ( pf_we          ),
    .obj_cpu_addr ( obj_cpu_addr   ),
    .obj_cpu_din  ( obj_cpu_din    ),
    .obj_cpu_dout ( obj_cpu_dout   ),
    .obj_we       ( obj_we         ),
    .bac06_addr   ( bac06_addr     ),
    .bac06_din    ( bac06_din      ),
    .bac06_dout   ( bac06_dout     ),
    .bac06_cs     ( bac06_cs       ),
    .bac06_rnw    ( bac06_rnw      ),
    .snd_latch    ( snd_latch      ),
    .snd_irq      ( snd_irq        ),
    .st_dout      ( st_main        )
);
/* verilator tracing_on */
jtpktgal_sound u_sound(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .cen_6      ( sndcpu_cen   ),
    .cen_jt03   ( ym2203_cen   ),
    .cen_opl2   ( ym3812_cen   ),
    .cen_pcm    ( pcm_cen      ),
    .rom_addr   ( snd_cpu_addr ),
    .rom_cs     ( snd_cs       ),
    .rom_data   ( snd_data     ),
    .rom_ok     ( snd_ok       ),
    .snd_latch  ( snd_latch    ),
    .snd_irq    ( snd_irq      ),
    .deco222    ( deco222      ),
    .jt03_fm    ( jt03_fm      ),
    .jt03_psg   ( jt03_psg     ),
    .ym3812     ( ym3812       ),
    .pcm        ( pcm          ),
    .st_dout    ( st_sound     )
);
/* verilator tracing_off */
jtpktgal_video u_video(
    .rst          ( rst          ),
    .clk          ( clk          ),
    .pxl_cen      ( pxl_cen      ),

    .pf_addr      ( pf_addr      ),
    .pf_data      ( pf_dout      ),
    .objram_addr  ( objram_addr  ),
    .objram_data  ( objram_dout  ),
    .bac06_addr   ( bac06_addr   ),
    .bac06_din    ( bac06_din    ),
    .bac06_dout   ( bac06_dout   ),
    .bac06_cs     ( bac06_cs     ),
    .bac06_rnw    ( bac06_rnw    ),
    .ioctl_addr   ( ioctl_addr[4:0] ),
    .ioctl_din    ( ioctl_bac06    ),
    .debug_bus    ( debug_bus    ),
    .char_orig    ( char_orig    ),
    .char_bootleg ( char_bootleg ),

    .char_addr    ( char_addr    ),
    .char_data    ( char_data    ),
    .char_ok      ( char_ok      ),
    .char_cs      ( char_cs      ),

    .obj_addr     ( obj_addr     ),
    .obj_data     ( obj_data     ),
    .obj_ok       ( obj_ok       ),
    .obj_cs       ( obj_cs       ),

    .promrg_addr  ( promrg_addr  ),
    .promrg_data  ( promrg_data  ),
    .promb_addr   ( promb_addr   ),
    .promb_data   ( promb_data   ),

    .HS           ( HS           ),
    .VS           ( VS           ),
    .LHBL         ( LHBL         ),
    .LVBL         ( LVBL         ),
    .red          ( red          ),
    .green        ( green        ),
    .blue         ( blue         ),
    .gfx_en       ( gfx_en       )
);

endmodule
