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

wire        m2s_set, hflip, vflip, swaitn,
            sx_c8, sx_d0, sx_d8, sx_e0, sx_e8;
wire        cen_psg, cen, sub_wrn;
wire [15:0] fix_dout;
wire signed [11:0] pcm;
wire [10:1] fix_addr;
wire [ 9:0] psg0, psg1;
wire [ 8:0] scrx;
wire [ 7:0] m2s, s2m, scry, sub_dout, sh_dout;

assign {cen_psg,cen} = 0;
assign {dip_flip, sample, main_cs, obj_cs} = 0;
assign {m2s_set, hflip, vflip, swaitn}     = 0;
assign scrx        =  9'b0;
assign debug_view  =  8'b0;
assign m2s         =  8'b0;
assign s2m         =  8'b0;
assign scry        =  8'b0;
assign sub_dout    =  8'b0;
assign sh_dout     =  8'b0;
assign snd         = 16'b0;
assign main_addr   = 16'b0;
assign fix_dout    = 16'b0;
assign obj_addr    = 14'b0;
assign fixram_addr = 10'b0;
assign sh_addr     = 10'b0;
assign pal_we      =  2'b0;
assign fix_we      =  2'b0;


jtwc_sub u_sub(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen           ),
    .vint       ( LHBL          ),       // video interrupt (LVBL)
    .waitn      ( swaitn        ),
    // shared memory
    .mmx_c8     ( sx_c8         ),
    .mmx_d0     ( sx_d0         ),
    .mmx_d8     ( sx_d8         ),
    .mmx_e0     ( sx_e0         ),
    .mmx_e8     ( sx_e8         ),
    .cpu_dout   ( sub_dout      ),
    .wr_n       ( sub_wrn       ),
    .sh_dout    ( sh_dout       ),
    // ROM access
    .rom_cs     ( sub_cs        ),
    .rom_addr   ( sub_addr      ),
    .rom_data   ( sub_data      ),
    .rom_ok     ( sub_ok        )
);

jtwc_sound u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen_psg    ( cen_psg       ),
    .cen_psg2   ( cen_psg2      ),
    .cen_pcm    ( cen_pcm       ),
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
    .pcm        ( pcm           )
);

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
    .fix_addr   ( fix_addr      ),
    .fix_dout   ( fix_dout      ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_cs    ( char_cs       ),
    .char_ok    ( char_ok       ),
    // Scroll
    .scrx       ( scrx          ),
    .scry       ( scry          ),
    .vram_addr  ( vram_addr     ),
    .vram_data  ( vram_data     ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_cs     ( scr_cs        ),
    .scr_ok     ( scr_ok        ),
    // Palette RAM
    .pal_addr   ( pal_addr      ),
    .pal_dout   ( pal_dout      ),
    // Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    // Debug
    .gfx_en     ( gfx_en        )
);

endmodule
