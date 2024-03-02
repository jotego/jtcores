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
    Date: 02-05-2020 */

module jtkiwi_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        sub_rnw, shr_cs, mshramen, snd_rstn;
wire [ 7:0] shr_din, shr_dout, main_st, gfx_st, snd_st,
            vram_dout, pal_dout, cpu_dout;
wire [ 8:0] hdump;
wire [ 1:0] eff_coin;
wire [12:0] shr_addr, cpu_addr;

wire        bram_cs, vram_cs,  pal_cs, pal2_cs, flip;
wire        cpu_rnw, vctrl_cs, vflag_cs,
            button_aid, // merges 1P, coin and
            colprom_we, mcuprom_we, eff_service;
reg         hb_dly=0, dip_flip_xor=0,
            coin_xor=0, banked_ram=0,
            kageki=0, kabuki=0, kabuki_mod = 0, service_xor=0,
            colprom_en=0, mcu_en=0, aid_en, fast_fm=0;

assign dip_flip   = ~flip ^ dip_flip_xor;
assign debug_view = st_addr[7:6]==0 ? { hb_dly, dip_flip_xor, coin_xor, banked_ram,
                                        kageki, kabuki, colprom_en, mcu_en } :
                    st_addr[7:6]==1 ? main_st :
                    st_addr[7:6]==2 ? gfx_st  : snd_st;
assign colprom_we = prom_we && prog_addr[15:10]==0;
assign mcuprom_we = prom_we && prog_addr >= `MCU_START;
assign st_dout    = debug_view;
// Banked RAM
assign bram_we    = bram_cs & ~cpu_rnw;
// assign bram_dsn   = { 1'd1, bram_cs & cpu_rnw };
assign bram_din   = cpu_dout;
// button_aid will make up/down inputs to work as coins too. This helps
// button mapping for spinners in MiSTer
assign eff_coin   = {2{coin_xor}}^( coin & ({2{~button_aid}}| {&joystick2[3:2],&joystick1[3:2]}));
assign eff_service= service_xor ^ service;
assign button_aid = `ifdef MISTER status[13]&aid_en `else 0 `endif ;

always @(posedge clk) begin
    if( prog_we && header ) begin
        if( prog_addr==0 )
            { hb_dly, dip_flip_xor, coin_xor, banked_ram,
              kageki, kabuki, colprom_en, mcu_en } <= prog_data;
        else if( prog_addr==1 )
            { kabuki_mod, fast_fm, aid_en, service_xor } <= prog_data[3:0];
    end
end

/* verilator tracing_on */
jtkiwi_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen6           ( cen6          ),

    .LVBL           ( LVBL          ),
    .hcnt           ( hdump         ),
    .colprom_en     ( colprom_en    ),
    // Banked RAM
    .banked_ram     ( banked_ram    ),
    .bram_cs        ( bram_cs       ),
    .bram_ok        ( 1'b1 ), //bram_ok       ),
    .bram_data      ( bram_dout     ),
    .bram_addr      ( bram_addr     ),
    // Main CPU ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),

    // Sub CPU access to shared RAM
    .shr_addr       ( shr_addr      ),
    .shr_dout       ( shr_dout      ),
    .sub_rnw        ( sub_rnw       ),
    .shr_din        ( shr_din       ),
    .shr_cs         ( shr_cs        ),
    .mshramen       ( mshramen      ),
    // Sound
    .snd_rstn       ( snd_rstn      ),

    // Video
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),

    .vctrl_cs       ( vctrl_cs      ),
    .vram_cs        ( vram_cs       ),
    .vflag_cs       ( vflag_cs      ),
    .vram_dout      ( vram_dout     ),

    .pal_cs         ( pal_cs        ),
    .pal_dout       ( pal_dout      ),
    .dip_pause      ( dip_pause     ),
    .debug_bus      ( debug_bus     ),
    .st_dout        ( main_st       )
);

/* verilator tracing_on */
jtkiwi_video u_video(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .clk_cpu        ( clk           ),

    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .hb_dly         ( hb_dly        ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .HS             ( HS            ),
    .VS             ( VS            ),
    .flip           ( flip          ),
    .hdump          ( hdump         ),
    // PROMs
    .prom_we        ( colprom_we    ),
    .prog_addr      ( prog_addr[9:0]),
    .prog_data      ( prog_data     ),
    .colprom_en     ( colprom_en    ),
    // GFX - CPU interface
    .cpu_rnw        ( cpu_rnw       ),
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),

    .vram_cs        ( vram_cs       ),
    .vctrl_cs       ( vctrl_cs      ),
    .vflag_cs       ( vflag_cs      ),
    .vram_dout      ( vram_dout     ),

    .pal_cs         ( pal_cs        ),
    .pal_dout       ( pal_dout      ),

    .pal2_cs        ( pal2_cs       ),
    .cpu2_dout      ( shr_din       ),
    .cpu2_rnw       ( sub_rnw       ),
    .cpu2_addr      ( shr_addr[9:0] ),

    // SDRAM
    .scr_addr       ( scr_addr      ),
    .scr_data       ( scr_data      ),
    .scr_ok         ( scr_ok        ),
    .scr_cs         ( scr_cs        ),

    .obj_addr       ( obj_addr      ),
    .obj_data       ( obj_data      ),
    .obj_ok         ( obj_ok        ),
    .obj_cs         ( obj_cs        ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Test
    .gfx_en         ( gfx_en        ),
    .debug_bus      ( debug_bus     ),
    .st_dout        ( gfx_st        )
);

/* verilator tracing_off */
jtkiwi_snd u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .snd_rstn   ( snd_rstn      ),
    .fast_fm    ( fast_fm       ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cen1p5     ( cen1p5        ),
    .LVBL       ( LVBL          ),
    .fm_en      ( enable_fm     ),
    .psg_en     ( enable_psg    ),

    // Game variations
`ifdef NOKABUKIZ
    .kabuki     ( 1'b0          ),
    .kabuki_mod ( 1'b0          ),
`else
    .kabuki     ( kabuki        ),
    .kabuki_mod ( kabuki_mod    ), // different memory map for TNZS
`endif
    .kageki     ( kageki        ),

    // PCM
    .pcm_addr   ( pcm_addr      ),
    .pcm_data   ( pcm_data      ),
    .pcm_ok     ( pcm_ok        ),
    .pcm_cs     ( pcm_cs        ),

    // cabinet I/O
    .cab_1p     ( cab_1p        ),
    .coin       ( eff_coin      ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .service    ( eff_service   ),
    .tilt       ( tilt          ),
    .dial_x     ( dial_x        ),
    .dial_y     ( dial_y        ),
    // DIP switches
    .dipsw      ( dipsw[15:0]   ),
    .dip_pause  ( dip_pause     ),

    // Shared RAM
    .ram_addr   ( shr_addr      ),
    .ram_din    ( shr_din       ),
    .ram_dout   ( shr_dout      ),
    .cpu_rnw    ( sub_rnw       ),
    .ram_cs     ( shr_cs        ),
    .mshramen   ( mshramen      ),
    .pal_cs     ( pal2_cs       ),
    .pal_dout   ( pal_dout      ),
    // MCU
    .mcu_en     ( mcu_en        ),
    .prog_addr  ( prog_addr[10:0]),
    .prog_data  ( prog_data     ),
    .prom_we    ( mcuprom_we    ),

    // ROM
    .rom_addr   ( sub_addr      ),
    .rom_cs     ( sub_cs        ),
    .rom_data   ( sub_data      ),

    .audiocpu_addr ( audiocpu_addr ),
    .audiocpu_cs   ( audiocpu_cs   ),
    .audiocpu_data ( audiocpu_data ),
    .audiocpu_ok   ( audiocpu_ok   ),

    // Sound output
    .fx_level   ( dip_fxlevel   ),
    .snd        ( snd           ),
    .sample     ( sample        ),
    .peak       ( game_led      ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_addr    ( st_addr       ),
    .st_dout    ( snd_st        )
);

endmodule
