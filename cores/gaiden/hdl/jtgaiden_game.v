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
    Date: 1-1-2025 */

module jtgaiden_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        nmi_set, flip, pre_ramwe, objdly, mcutype, vsize_en;
wire [ 1:0] frmbuf_en;
wire [ 7:0] snd_cmd, obj_y, vregs;
wire [15:0] txt_x, txt_y, scra_x, scra_y, scrb_x, scrb_y;

assign dip_flip  = flip;
assign ioctl_din = vregs;
assign debug_view= {5'd0,objdly,frmbuf_en};
assign ram_addr  = main_addr[13:1];

wire [1:0] ram_dsn;
wire [15:0] ram_data = ram_dout;
wire ram_cs, ram_ok, ramcs_l;
assign ram_we = {2{pre_ramwe}} & ~ram_dsn;
assign ram_ok = ramcs_l | ~ram_cs;
jtframe_sh #(.W(1),.L(2)) u_sh(clk,1'b1,ram_cs,ramcs_l);

jtgaiden_header u_header (
    .clk      ( clk             ),
    .header   ( header          ),
    .prog_we  ( prog_we         ),
    .prog_addr( prog_addr[2:0]  ),
    .prog_data( prog_data       ),
    .frmbuf   ( frmbuf_en       ),
    .objdly   ( objdly          ),
    .mcutype  ( mcutype         ),
    .vsize_en ( vsize_en        )
);

jtgaiden_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .LVBL       ( LVBL      ),
    .mcutype    ( mcutype   ),

    .main_addr  ( main_addr ),
    .main_dout  ( ram_din   ),
    .rom_cs     ( main_cs   ),
    .ram_cs     ( ram_cs    ),
    .ram_we     ( pre_ramwe ),
    .dsn        ( ram_dsn   ),

    .nmi_set    ( nmi_set   ),
    .snd_cmd    ( snd_cmd   ),
    // video memories
    .txt_we     ( txt_we    ),
    .scra_we    ( scra_we   ),
    .scrb_we    ( scrb_we   ),
    .obj_we     ( obj_we    ),
    .pal_we     ( pal_we    ),

    .mt_dout    ( mt_dout   ),
    .mo_dout    ( mo_dout   ),
    .mp_dout    ( mp_dout   ),
    .ma_dout    ( ma_dout   ),
    .mb_dout    ( mb_dout   ),

    // video registers
    .flip       ( flip      ),
    .txt_x      ( txt_x     ),
    .txt_y      ( txt_y     ),
    .scra_x     ( scra_x    ),
    .scra_y     ( scra_y    ),
    .scrb_x     ( scrb_x    ),
    .scrb_y     ( scrb_y    ),
    .obj_y      ( obj_y     ),

    .ram_dout   ( ram_data  ),
    .rom_data   ( main_data ),
    .ram_ok     ( ram_ok    ),
    .rom_ok     ( main_ok   ),

    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .cab_1p     (cab_1p[1:0]),
    .coin       ( coin[1:0] ),
    .dip_pause  ( dip_pause ),
    .dipsw      (dipsw[15:0]),

    .ioctl_addr (ioctl_addr[3:0]),
    .ioctl_din  ( vregs     )
);

jtgaiden_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        ),
    .flip       ( flip      ),
    .frmbuf_en  ( frmbuf_en ),
    .objdly     ( objdly    ),
    .vsize_en   ( vsize_en  ),

    // scroll registers
    .txt_y      ( txt_y     ),
    .scra_y     ( scra_y    ),
    .scrb_y     ( scrb_y    ),
    .txt_x      ( txt_x     ),
    .scra_x     ( scra_x    ),
    .scrb_x     ( scrb_x    ),
    .obj_y      ( obj_y     ),

    // Video RAM
    .tram_addr  ( tram_addr ),
    .tram_dout  ( tram_dout ),

    .scra_addr  ( scra_addr ),
    .scra_dout  ( scra_dout ),

    .scrb_addr  ( scrb_addr ),
    .scrb_dout  ( scrb_dout ),

    .oram_addr  ( oram_addr ),
    .oram_dout  ( oram_dout ),

    .pal_addr   ( pal_addr  ),
    .pal_dout   ( pal_dout  ),

    .txt_cs     ( txt_cs    ),
    .txt_addr   ( txt_addr  ),
    .txt_ok     (txt_ok     ),
    .txt_data   (txt_data   ),

    .scr1_cs    ( scr1_cs   ),
    .scr1_addr  ( scr1_addr ),
    .scr1_data  ( scr1_data ),
    .scr1_ok    ( scr1_ok   ),

    .scr2_cs    ( scr2_cs   ),
    .scr2_addr  ( scr2_addr ),
    .scr2_data  ( scr2_data ),
    .scr2_ok    ( scr2_ok   ),

    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_ok     ( obj_ok    ),
    .obj_data   ( obj_data  ),
    // Colours
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    // Test
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);
/* verilator tracing_off */
jtgaiden_sound u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen4       ( cen4      ),
    .cen1       ( cen1      ),

    .cmd        ( snd_cmd   ),
    .nmirq      ( nmi_set   ),
    // ROM
    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),
    // ADPCM ROM
    .pcm_addr   ( pcm_addr  ),
    .pcm_cs     ( pcm_cs    ),
    .pcm_data   ( pcm_data  ),
    .pcm_ok     ( pcm_ok    ),
    // Sound
    .fm0        ( fm0       ),
    .fm1        ( fm1       ),
    .psg0       ( psg0      ),
    .psg1       ( psg1      ),
    .pcm        ( pcm       )
);

endmodule
