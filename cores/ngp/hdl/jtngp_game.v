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
    Date: 22-3-2022 */

module jtngp_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:1] cpu_addr;
wire [15:0] cha_dout, obj_dout, scr1_dout, scr2_dout, regs_dout;
wire [15:0] cpu_dout, gfx_dout, shd_dout;
wire [ 7:0] sub_comm;
wire [ 1:0] we, shd_we;
wire        gfx_cs;
wire        cpu_cen, snd_cen, snd_ack, snd_nmi, snd_irq, snd_en, snd_rstn;
wire        hirq, virq, snd_nmi, main_int5;

wire signed [ 7:0] snd_dacl, snd_dacr;

assign debug_view = 0;
assign game_led  = 0;

assign rom_addr = cpu_addr;
assign dip_flip = 0;

// jtngp_sdram u_sdram(
//     .rst        ( rst           ),
//     .clk        ( clk           ),

//     .downloading( downloading   ),
//     .dwnld_busy ( dwnld_busy    ),

//     .ioctl_addr ( ioctl_addr    ), // max 64 MB
//     .ioctl_dout ( ioctl_dout    ),
//     .ioctl_wr   ( ioctl_wr      ),
//     .ioctl_idx  ( ioctl_idx     ),
//     .prog_addr  ( prog_addr     ),
//     .prog_data  ( prog_data     ),
//     .prog_mask  ( prog_mask     ), // active low
//     .prog_we    ( prog_we       ),
//     .prog_rd    ( prog_rd       ),
//     .prog_ba    ( prog_ba       ),

//     .sdram_ack  ( sdram_ack     )
// );

jtngp_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen6       ( cen6      ),
    .phi1_cen   ( phi1_cen  ),

    // interrupt sources
    .lvbl       ( LVBL      ),
    // player inputs
    .joystick1  ( joystick1 ),
    .start_button(start_button[0]),
    // Bus access
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .gfx_dout   ( gfx_dout  ),
    .we         ( we        ),
    .shd_we     ( shd_we    ),
    .shd_dout   ( shd_dout  ),
    .gfx_cs     ( gfx_cs    ),

    // Sound
    .snd_nmi    ( snd_nmi   ),
    .snd_irq    ( snd_irq   ),
    .snd_rstn   ( snd_rstn  ),
    .snd_en     ( snd_en    ),
    .snd_ack    ( snd_ack   ),
    .snd_dacl   ( snd_dacl  ),
    .snd_dacr   ( snd_dacr  ),
    .main_int5  ( main_int5 ),

    // Cartridge
    .flash0_cs  (           ),
    .flash1_cs  (           ),

    // Firmware access
    .rom_data   ( rom_data  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
);

jtngp_snd u_snd(
    .rstn       ( snd_rstn  ),
    .clk        ( clk       ),
    .cen3       ( cen3      ),

    .snd_en     ( snd_en    ),
    .snd_dacl   ( snd_dacl  ),
    .snd_dacr   ( snd_dacr  ),

    .main_addr  (cpu_addr[11:1]),
    .main_dout  ( cpu_dout  ),
    .main_din   ( shd_dout  ),
    .main_we    ( shd_we    ),
    .main_int5  ( main_int5 ),
    .comm       ( sub_comm  ),      // where do we store these 8 bits?
    .irq_ack    ( snd_ack   ),
    .nmi        ( snd_nmi   ),
    .irq        ( snd_irq   ),

    .sample     ( sample    ),
    .snd_l      ( snd_left  ),
    .snd_r      ( snd_right )
);

/* verilator tracing_off */
jtngp_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    .status     ( status    ),
    .cpu_cen    ( cpu_cen   ),
    .snd_cen    ( snd_cen   ),

    // CPU
    .cpu_addr   (cpu_addr[13:1]),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( gfx_dout  ),
    .we         ( we        ),
    .gfx_cs     ( gfx_cs    ),

    .hirq       ( hirq      ),
    .virq       ( virq      ),

    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .gfx_en     ( gfx_en    )
);

endmodule