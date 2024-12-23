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
    Date: 13-1-2022 */

module jtmikie_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// SDRAM offsets
localparam [21:0] SND_START   =  `SND_START,
                  SCR_START   =  `SCR_START,
                  OBJ_START   =  `OBJ_START;

localparam [24:0] PROM_START  =  `JTFRAME_PROM_START;

wire [ 7:0] dipsw_a, dipsw_b;
wire [ 1:0] dipsw_c;
wire        V16;

wire [ 2:0] pal_sel;
wire        cpu_cen;
wire        cpu_rnw, cpu_irqn, cpu_nmin;
wire        vram_cs, objram_cs, flip;
wire [ 7:0] vscr_dout, vram_dout, obj_dout, cpu_dout;
wire        vsync60;
wire        snd_cen, psg_cen;

// PCM
wire [ 7:0] snd_latch;

wire        m2s_on;

assign { dipsw_c, dipsw_b, dipsw_a } = dipsw[17:0];
assign dip_flip = dipsw_c[0];
assign debug_view = 0;

always @(*) begin
    post_data = prog_data;
    pre_addr  = ioctl_addr;
    if( ioctl_addr[21:0] >= SCR_START && ioctl_addr[21:0]<OBJ_START ) begin
        post_data = { prog_data[3:0], prog_data[7:4] };
    end
    if( ioctl_addr[21:0] >= OBJ_START && ioctl_addr[24:0]<PROM_START ) begin
        pre_addr[15]  =  ioctl_addr[0];
        pre_addr[14]  =  ioctl_addr[15];
        pre_addr[0]   =  ~ioctl_addr[14];
        case( ioctl_addr[5:4])
            0: {pre_addr[2:1]} = 1;
            1: {pre_addr[2:1]} = 2;
            2: {pre_addr[2:1]} = 3;
            3: {pre_addr[2:1]} = 0;
        endcase
        pre_addr[6:3] =  { ioctl_addr[6], ioctl_addr[3:1] };
    end
end

`ifndef NOMAIN
jtmikie_main u_main(
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
    .service        ( service       ),
    // GFX
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),

    .vram_cs        ( vram_cs       ),
    .vram_dout      ( vram_dout     ),
    .vscr_dout      ( vscr_dout     ),

    .objram_cs      ( objram_cs     ),
    .obj_dout       ( obj_dout      ),
    // Sound control
    .snd_latch      ( snd_latch     ),
    .snd_on         ( m2s_on        ),
    // GFX configuration
    .pal_sel        ( pal_sel       ),
    .flip           ( flip          ),
    // interrupt triggers
    .LVBL           ( LVBL          ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       ),
    .dipsw_c        ( dipsw_c       )
);
`else
    assign main_cs = 0;
    assign objram_cs = 0;
    assign snd     = 0;
    assign sample  = 0;
    assign game_led= 0;
    `ifndef PALSEL
    `define PALSEL 0
    `endif
    assign pal_sel = `PALSEL;
    assign flip    = 0;
`endif

`ifndef NOSOUND
jtmikie_snd u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),
    // ROM
    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),
    // From main CPU
    .main_latch ( snd_latch ),
    .m2s_on     ( m2s_on    ),
    // Sound
    .snd        ( snd       ),
    .sample     ( sample    ),
    .peak       ( game_led  )
);
`else
    assign snd_cs=0;
    assign snd_addr=0;
    assign snd=0;
    assign sample=0;
    assign game_led=0;
`endif

jtmikie_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),

    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    // configuration
    .pal_sel    ( pal_sel   ),
    .flip       ( flip      ),

    // CPU interface
    .cpu_addr   ( main_addr[10:0]  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_rnw    ( cpu_rnw   ),
    // Scroll
    .vram_cs    ( vram_cs   ),
    .vscr_cs    ( 1'b0      ),
    .vram_dout  ( vram_dout ),
    .vscr_dout  ( vscr_dout ),
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
    .obj_addr   ( objrom_addr  ),
    .obj_data   ( objrom_data  ),
    .obj_cs     ( objrom_cs ),
    .obj_ok     ( objrom_ok    ),

    .V16        ( V16       ),
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
