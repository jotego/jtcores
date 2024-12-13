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
    Date: 26-10-2024 */

module jtwc_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        m2s_set, hflip, vflip, mwait, swait, m_wrn, sub_wrn,
            mx_c8, mx_d0, mx_d8, mx_e0, mx_e8,
            sx_c8, sx_d0, sx_d8, sx_e0, sx_e8,
            mute_n, srst_n, cen_pause;
wire [ 8:0] scrx;
wire [ 7:0] mdout, m2s, s2m, scry, sub_dout, sha_dout, form0, st_main;
reg         bootleg;

assign dip_flip   = vflip | hflip;
assign debug_view = st_main; // form0;
assign ioctl_din  = 0;
assign cen_pause  = cen_cpu & dip_pause;

always @(posedge clk) begin
    if( prog_addr==0 && prog_we && header )
        bootleg <= prog_data[0];
end

/* verilator tracing_on */
jtwc_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_pause     ),
    .ws         ( mwait         ),
    .lvbl       ( LVBL          ),      // video interrupt
    // Cabinet inputs
    .bootleg    ( bootleg       ),      // non-symmetrical speed
    .dial_x     ( dial_x        ),
    .dial_y     ( dial_y        ),
    .cab_1p     ( cab_1p[1:0]   ),
    .coin       ( coin[1:0]     ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .joyana_l1  ( joyana_l1     ),
    .joyana_l2  ( joyana_l2     ),
    .form0      ( form0         ),
    // shared memory
    .mmx_c8     ( mx_c8         ),
    .mmx_d0     ( mx_d0         ),
    .mmx_d8     ( mx_d8         ),
    .mmx_e0     ( mx_e0         ),
    .mmx_e8     ( mx_e8         ),
    .cpu_dout   ( mdout         ),
    .wr_n       ( m_wrn         ),
    .sh_dout    ( sha_dout      ),
    // sound
    .m2s        ( m2s           ),
    .s2m        ( s2m           ),
    .m2s_set    ( m2s_set       ),
    // control
    .hflip      ( hflip         ),
    .vflip      ( vflip         ),
    .mute_n     ( mute_n        ),
    .srst_n     ( srst_n        ),
    // ROM access
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    //
    .dipsw      ( dipsw[21:0]   ),
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_main       )
);

jtwc_sub u_sub(
    .rst_n      ( srst_n        ),
    .clk        ( clk           ),
    .cen        ( cen_pause     ),
    .lvbl       ( LVBL          ),       // video interrupt (LVBL)
    .ws         ( swait         ),
    // shared memory
    .mmx_c8     ( sx_c8         ),
    .mmx_d0     ( sx_d0         ),
    .mmx_d8     ( sx_d8         ),
    .mmx_e0     ( sx_e0         ),
    .mmx_e8     ( sx_e8         ),
    .cpu_dout   ( sub_dout      ),
    .wr_n       ( sub_wrn       ),
    .sh_dout    ( sha_dout      ),
    // ROM access
    .rom_cs     ( sub_cs        ),
    .rom_addr   ( sub_addr      ),
    .rom_data   ( sub_data      ),
    .rom_ok     ( sub_ok        )
);

jtwc_shared u_shared(
    .rst        ( rst           ),
    .clk        ( clk           ),
    // main
    .ma         (main_addr[10:0]),
    .mdout      ( mdout         ),
    .mwr_n      ( m_wrn         ),
    .mxc8       ( mx_c8         ),
    .mxd0       ( mx_d0         ),
    .mxd8       ( mx_d8         ),
    .mxe0       ( mx_e0         ),
    .mxe8       ( mx_e8         ),
    .msw        ( mwait         ),
    // sub
    .sa         ( sub_addr[10:0]),
    .sdout      ( sub_dout      ),
    .swr_n      ( sub_wrn       ),
    .sxc8       ( sx_c8         ),
    .sxd0       ( sx_d0         ),
    .sxd8       ( sx_d8         ),
    .sxe0       ( sx_e0         ),
    .sxe8       ( sx_e8         ),
    .ssw        ( swait         ),
    // mux'ed
    .sha        ( shram_addr    ),
    .sha_din    ( shram_din     ),
    .shram_we   ( shram_we      ),
    .pal_we     ( pal_we        ),
    .fix_we     ( fix_we        ),
    .obj_we     ( obj_we        ),
    .scr_we     ( vram_we       ),
    .shram_dout ( shram_dout    ),
    .pal16_dout ( pal16_dout    ),
    .fix16_dout ( fix16_dout    ),
    .vram16_dout( vram16_dout   ),
    .obj_dout   ( obj_dout      ),
    .sha_dout   ( sha_dout      ),
    // video scroll
    .scrx       ( scrx          ),
    .scry       ( scry          )
);
/* verilator tracing_on */
jtwc_sound u_sound(
    .rst_n      ( mute_n        ),
    .clk        ( clk           ),
    .cen_psg    ( cen_psg1      ),
    .cen_psg2   ( cen_psg2      ),
    .cen_pcm    ( cen_pcm       ),
    .vbl        ( ~LVBL         ),
    .m2s_set    ( m2s_set       ),
    .m2s        ( m2s           ),
    .s2m        ( s2m           ),
    // ROM access
    .rom_cs     ( snd_cs        ),
    .rom_addr   ( snd_addr      ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),
    // PCM ROM
    .pcm_cs     ( pcm_cs        ),
    .pcm_addr   ( pcm_addr      ),
    .pcm_data   ( pcm_data      ),
    .pcm_ok     ( pcm_ok        ),
    // Sound output
    .psg0       ( psg0          ),
    .psg1       ( psg1          ),
    .pcm        ( pcmsnd        ),
    .debug_bus  ( debug_bus     ),
    .st_dout    (               )
);
/* verilator tracing_on */
jtwc_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .hflip      ( hflip         ),
    .vflip      ( vflip         ),
    .lhbl       ( LHBL          ),
    .lvbl       ( LVBL          ),
    .vs         ( VS            ),
    .hs         ( HS            ),
    // Character (fix) RAM
    .fix_addr   ( fixram_addr   ),
    .fix_dout   ( fixram_dout   ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_cs    ( char_cs       ),
    .char_ok    ( char_ok       ),
    // Scroll
    .scrx       ( scrx          ),
    .scry       ( scry          ),
    .vram_addr  ( vram_addr     ),
    .vram_data  ( vram_dout     ),
    // .vram_data  ( {vram_dout[7:0], vram_dout[15:8]}   ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_cs     ( scr_cs        ),
    .scr_ok     ( scr_ok        ),
    // Objects
    .oram_addr  ( objram_addr   ),
    .oram_data  ( objram_dout   ),
    .fb_addr    ( fb_addr       ),
    .fb_din     ( fb_din        ),
    .fb_dout    ( fb_dout       ),
    .fb_we      ( fb_we         ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_cs     ( obj_cs        ),
    .obj_ok     ( obj_ok        ),
    // Palette RAM
    .pal_addr   ( pal_addr      ),
    .pal_dout   ( pal_dout      ),
    // Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .gfx_en     ( gfx_en        )
);

endmodule
