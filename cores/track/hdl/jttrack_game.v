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
    Date: 19-3-2022 */

module jttrack_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// SDRAM offsets
localparam [21:0] SND_START   =  `SND_START,
                  SCR_START   =  `SCR_START,
                  OBJ_START   =  `OBJ_START,
                  PCM_START   =  `PCM_START;
localparam [24:0] PROM_START  =  `JTFRAME_PROM_START;

wire [ 7:0] dipsw_a, dipsw_b;

wire        cpu_cen;
wire        cpu_rnw, cpu_irqn, cpu_nmin;
wire        vram_cs, objram_cs, flip;
wire [ 7:0] vram_dout, obj_dout, cpu_dout;

wire        m2s_irq, m2s_data;
wire        main_pause;
wire        is_scr, is_obj;

assign { dipsw_b, dipsw_a } = dipsw[15:0];
assign dip_flip   = ~flip;
assign main_pause = dip_pause & ~ioctl_ram;
assign pcm_cs     = 1;

assign is_scr   = ioctl_addr[21:0] >= SCR_START && ioctl_addr[21:0]<OBJ_START;
assign is_obj   = ioctl_addr[21:0] >= OBJ_START && ioctl_addr[21:0]<PCM_START;

always @(*) begin
    post_data = prog_data;
    post_addr = prog_addr;
    if( is_scr ) begin
        post_addr[0] = ~prog_addr[0];
    end
    if( is_obj ) begin
        post_addr[4:0] = { prog_addr[2:0], ~prog_addr[4], ~prog_addr[3] };
    end
end

`ifndef NOMAIN
jttrack_main u_main(
    .rst            ( rst24         ),
    .clk            ( clk24         ),        // 24 MHz
    .cpu4_cen       ( cpu4_cen      ),
    .cpu_cen        ( cpu_cen       ),
    // ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       ),
    // cabinet I/O
    .cab_1p         ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .joystick3      ( joystick3     ),
    .joystick4      ( joystick4     ),
    .service        ( service       ),
    // GFX
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),

    .vram_cs        ( vram_cs       ),
    .vram_dout      ( vram_dout     ),

    .objram_cs      ( objram_cs     ),
    .obj_dout       ( obj_dout      ),
    // Sound control
    .snd_data_cs    ( m2s_data      ),
    .snd_irq        ( m2s_irq       ),
    // GFX configuration
    .flip           ( flip          ),
    // interrupt triggers
    .LVBL           ( LVBL          ),
    // DIP switches
    .dip_pause      ( main_pause    ),
    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       ),
    // NVRAM
    .clk48          ( clk           ),
    .ioctl_ram      ( ioctl_ram     ),
    .ioctl_dout     ( prog_data     ),
    .ioctl_din      ( ioctl_din     ),
    .ioctl_wr       ( prog_we       ),
    .ioctl_addr     ( prog_addr[15:0])
);
`else
    assign main_cs   = 0;
    assign main_addr = 0;
    assign cpu_rnw   = 1;
    assign vram_cs   = 0;
    assign cpu_dout  = 0;
    assign m2s_irq   = 0;
    assign m2s_data  = 0;
    assign objram_cs = 0;
    assign snd       = 0;
    assign sample    = 0;
    assign game_led  = 0;
    assign flip      = 0;
    assign pcm_addr  = 0;
`endif

`ifndef NOSOUND
jttrack_snd u_sound(
    .rst        ( rst       ),
    .clk        ( clk24     ),
    .snd_cen    ( snd_cen   ),    // 3.5MHz
    .psg_cen    ( psg_cen   ),    // 1.7MHz
    // ROM
    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),
    // From main CPU
    .main_dout  ( cpu_dout  ),
    .m2s_data   ( m2s_data  ),
    .m2s_irq    ( m2s_irq   ),
    // Sound
    .pcm_addr   ( pcm_addr  ),
    .pcm_data   ( pcm_data  ),
    .pcm_ok     ( pcm_ok    ),
    // sound output
    .psg        ( psg       ),
    .vlm        ( vlm       ),
    .rdac       ( rdac      ),
    .vlm_rcen   ( vlm_rcen  ),
    .psg_rcen   ( psg_rcen  ),
    .rdac_rcen  ( rdac_rcen ),
    .debug_view (debug_view )
);
`else
    assign snd_cs=0;
    assign snd_addr=0;
    assign pcm_addr=0;
    assign snd=0;
    assign sample=0;
    assign game_led=0;
    assign debug_view = 0;
`endif

jttrack_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),

    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    // configuration
    .flip       ( flip      ),

    // CPU interface
    .cpu_addr   ( main_addr[11:0]  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_rnw    ( cpu_rnw   ),
    // Scroll
    .vram_cs    ( vram_cs   ),
    .vram_dout  ( vram_dout ),
    // Objects
    .objram_cs  ( objram_cs ),
    .obj_dout   ( obj_dout  ),

    // PROMs
    .prog_data  ( prog_data ),
    .prog_addr  ( prog_addr[10:0] ),
    .prom_en    ( prom_we   ),

    // Scroll
    .scr_addr   ( scr_addr  ),
    .scr_data   ( scr_data  ),
    .scr_ok     ( scr_ok    ),
    // Objects
    .obj_addr   ( objrom_addr ),
    .obj_data   ( objrom_data ),
    .obj_cs     ( objrom_cs ),
    .obj_ok     ( objrom_ok ),

    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

endmodule
