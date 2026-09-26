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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 7-8-2026 */

module jtvlfied_game(
    `include "jtframe_game_ports.inc"
);

wire [15:0] fb_dout, vctrl_dout;
wire [ 1:0] main_dsn;
wire        obj_cs, ram_cs, fb_cs, pal_cs, vmask_cs, sprctrl_cs, vctrl_cs, main_rnw;
wire        sn_we, sn_rd, main_cen;
wire        flip;
wire [ 7:0] sn_dout;
wire [ 3:0] obj_pal;

wire        cchip_cs;
wire [11:1] cchip_addr;
wire [ 7:0] cchip_dout;
wire        cchip_rnw;
wire        fb_ok;

assign dip_flip   = 1'b0;
assign flip       = ~dipsw[1];   // DSWA bit1: 0 = Flip Screen On
assign st_dout    = 0;
// debug_view carries video_ctrl / video_mask, selected by debug_bus
assign cchip_rnw  = main_rnw | main_dsn[0];

assign ram_we = {2{ram_cs & ~main_rnw}} & ~main_dsn;
assign pal_we    = {2{pal_cs & ~main_rnw}} & ~main_dsn;
assign objram_we = {2{obj_cs & ~main_rnw}} & ~main_dsn;
assign ioctl_din = 0;

jtvlfied_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .LVBL       ( LVBL      ),

    .main_addr  ( main_addr ),
    .main_dout  ( main_dout ),
    .main_dsn   ( main_dsn  ),
    .main_rnw   ( main_rnw  ),
    .rom_cs     ( main_cs   ),
    .ram_cs     ( ram_cs    ),
    .obj_cs     ( obj_cs    ),
    .fb_cs      ( fb_cs     ),
    .pal_cs     ( pal_cs    ),
    .oram_dout  ( objram2main_data ),
    .vmask_cs   ( vmask_cs  ),
    .sprctrl_cs ( sprctrl_cs),
    .vctrl_cs   ( vctrl_cs  ),
    .obj_pal    ( obj_pal   ),

    .pal_dout   ( pal_dout  ),
    .fb_dout    ( fb_dout   ),
    .vctrl_dout ( vctrl_dout),
    .ram_dout   ( ram_dout  ),
    .rom_data   ( main_data ),
    .rom_ok     ( main_ok   ),

    // C-chip
    .cchip_cs   ( cchip_cs  ),
    .cchip_addr ( cchip_addr),
    .cchip_dout ( cchip_dout),
    .fb_ok      ( fb_ok     ),

    // Sound interface
    .cpu_cen    ( main_cen  ),
    .sn_dout    ( sn_dout   ),
    .sn_rd      ( sn_rd     ),
    .sn_we      ( sn_we     ),

    .dip_pause  ( dip_pause )
);

jtvlfied_cchip u_cchip(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cchip_cen ),

    .cs         ( cchip_cs  ),
    .addr       ( cchip_addr),
    .din        ( main_dout[7:0] ),
    .dout       ( cchip_dout),
    .rnw        ( cchip_rnw ),
    .LVBL       ( LVBL      ),

    .joystick1  ( joystick1[4:0] ),
    .joystick2  ( joystick2[4:0] ),
    .start_button( cab_1p[1:0] ),
    .coin       ( coin[1:0] ),
    .service    ( service   ),
    .tilt       ( tilt      ),

    .cchip_mask_addr ( cchip_mask_addr  ),
    .cchip_mask_data ( cchip_mask_data  ),
    .cchip_eprom_addr( cchip_eprom_addr ),
    .cchip_eprom_data( cchip_eprom_data )
);

jtvlfied_snd u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .fm_cen     ( fm_cen    ),
    .main_cen   ( main_cen  ),
    .main_addr  ( main_addr[1]   ),
    .main_dout  ( main_dout[3:0] ),
    .main_din   ( sn_dout[3:0]   ),
    .main_rnw   ( main_rnw  ),
    .sn_we      ( sn_we     ),
    .sn_rd      ( sn_rd     ),

    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_ok     ( snd_ok    ),
    .rom_data   ( snd_data  ),

    .dipsw_a    ( dipsw[ 7:0] ),
    .dipsw_b    ( dipsw[15:8] ),

    .fm         ( fm        ),     // -> mem.yaml channel 'fm'
    .psg        ( psg       )      // -> mem.yaml channel 'psg'
);

assign sn_dout[7:4] = 4'hf;

jtvlfied_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .flip       ( flip      ),

    .main_addr  ( main_addr[18:1] ),
    .main_dout  ( main_dout ),
    .fb_dout    ( fb_dout   ),
    .vctrl_dout ( vctrl_dout),
    .main_dsn   ( main_dsn  ),
    .main_rnw   ( main_rnw  ),
    .fb_cs      ( fb_cs     ),
    .fb_ok      ( fb_ok     ),
    .vmask_cs   ( vmask_cs  ),
    .vctrl_cs   ( vctrl_cs  ),
    .obj_pal    ( obj_pal   ),       // sprite palette bank from sprite_ctrl_w

    .pal_addr   ( palrd_addr),
    .pal_data   ( pal_data  ),

    .objram_addr( objram_addr ),
    .objram_dout( objram_dout ),

    .orom_addr  ( orom_addr ),
    .orom_data  ( orom_data ),
    .orom_cs    ( orom_cs   ),
    .orom_ok    ( orom_ok   ),

    // bitmap framebuffer — SDRAM bank 3
    .fbram_addr ( fbram_addr),
    .fbram_dsn  ( fbram_dsn ),
    .fbram_we   ( fbram_we  ),
    .fbram_cs   ( fbram_sel ),   // name comes from the cs: key in mem.yaml
    .fb_wdata   ( fb_wdata  ),
    .fbram_data ( fbram_data),
    .fbram_ok   ( fbram_ok  ),
    .fbrd_addr  ( fbrd_addr ),
    .fbrd_cs    ( fbrd_cs   ),
    .fbrd_data  ( fbrd_data ),
    .fbrd_ok    ( fbrd_ok   ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( debug_view)
);

endmodule
