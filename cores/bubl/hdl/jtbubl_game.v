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

module jtbubl_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        snd_rstn, black_n, flip;
wire [ 7:0] snd_latch, main_latch;
reg  [ 7:0] debug_mux;

reg         tokio;
wire [ 7:0] dipsw_a, dipsw_b;
wire        main_flag, main_stb, snd_stb;

wire [12:0] cpu_addr;
wire        vram_cs,  pal_cs;
wire        cpu_rnw, cpu_irqn;
wire [ 7:0] vram_dout, pal_dout, cpu_dout;
wire        snd_flag;

assign debug_view = debug_mux;
assign { dipsw_b, dipsw_a }   = dipsw[15:0];
assign dip_flip               = flip;

`ifdef SIMULATION
`ifndef LOADROM
    `ifdef TOKIO
    initial tokio=1;
    `else
    initial tokio=0;
    `endif
`endif
`endif

always @(posedge clk) begin
    if( prog_we && ioctl_addr==1 )
        tokio <= prog_data==8'h7e; // single byte detection. Both tokyo and tokyob start like this
end

always @(posedge clk) begin
    case( debug_bus[1:0] )
        0: debug_mux <= { 3'd0, snd_rstn, 3'd0, tokio};
        1: debug_mux <= main_latch;
        2: debug_mux <= snd_latch;
        default: debug_mux <= 0;
    endcase
end

`ifndef NOMAIN
jtbubl_main u_main(
    .rst            ( rst24         ),
    .clk24          ( clk24         ),        // 24 MHz
    .cen6           ( cen6          ),
    .cen4           ( cen4          ),

    .tokio          ( tokio         ),
    // Main CPU ROM
    .main_rom_addr  ( main_addr     ),
    .main_rom_cs    ( main_cs       ),
    .main_rom_ok    ( main_ok       ),
    .main_rom_data  ( main_data     ),
    // Sub CPU ROM
    .sub_rom_addr   ( sub_addr      ),
    .sub_rom_cs     ( sub_cs        ),
    .sub_rom_ok     ( sub_ok        ),
    .sub_rom_data   ( sub_data      ),
    // MCU ROM
    .mcu_rom_addr   ( mcu_addr      ),
    .mcu_rom_cs     ( mcu_cs        ),
    .mcu_rom_ok     ( mcu_ok        ),
    .mcu_rom_data   ( mcu_data      ),

    // Sound
    .snd_latch      ( snd_latch     ),
    .snd_stb        ( snd_stb       ),
    .snd_flag       ( snd_flag      ),
    .main_stb       ( main_stb      ),
    .main_flag      ( main_flag     ),
    .main_latch     ( main_latch    ),
    .snd_rstn       ( snd_rstn      ),
    // cabinet I/O
    .start_button   ( start_button  ),
    .coin_input     ( coin_input    ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .service        ( service       ),
    // Video
    .LVBL           ( LVBL          ),
    .flip           ( flip          ),
    .black_n        ( black_n       ),
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),
    .vram_cs        ( vram_cs       ),
    .vram_dout      ( vram_dout     ),
    .pal_cs         ( pal_cs        ),
    .pal_dout       ( pal_dout      ),

    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       )
);
`else
assign main_cs = 0;
assign cpu_rnw = 1;
assign vram_cs = 0;
assign pal_cs  = 0;
assign black_n = 1;
`endif

jtbubl_video u_video(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .clk_cpu        ( clk24         ),
    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .HS             ( HS            ),
    .VS             ( VS            ),
    .flip           ( flip          ),
    .dip_pause      ( dip_pause     ),
    .start_button   ( &start_button ),
    // PROMs
    .prom_we        ( prom_we       ),
    .prog_addr      ( prog_addr[7:0]),
    .prog_data      ( prog_data[3:0]),
    // GFX - CPU interface
    .vram_cs        ( vram_cs       ),
    .pal_cs         ( pal_cs        ),
    .cpu_rnw        ( cpu_rnw       ),
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .vram_dout      ( vram_dout     ),
    .pal_dout       ( pal_dout      ),
    .black_n        ( black_n       ),
    // SDRAM
    .rom_addr       ( gfx_addr      ),
    .rom_data       ( gfx_data      ),
    .rom_ok         ( gfx_ok        ),
    .rom_cs         ( gfx_cs        ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Test
    .gfx_en         ( gfx_en        )
);

reg snd_rstn_eff;

always @(negedge clk) begin
    snd_rstn_eff <= tokio ? ~snd_rstn : ~rst;
end

`ifndef NOSOUND
jtbubl_sound u_sound(
    .rst        ( rst24         ),
    .clk        ( clk24         ), // 24 MHz
    .rstn       ( snd_rstn_eff  ),
    .cen3       ( cen3          ),
    .fx_level   ( dip_fxlevel   ),

    .tokio      ( tokio         ),
    // communication with main CPU
    .snd_latch  ( snd_latch     ),
    .main_latch ( main_latch    ),
    .snd_stb    ( snd_stb       ),
    .main_stb   ( main_stb      ),
    .snd_flag   ( snd_flag      ),
    .main_flag  ( main_flag     ),
    // ROM
    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),

    // Sound output
    .snd        ( snd           ),
    .sample     ( sample        ),
    .peak       ( game_led      )
);
`else
assign snd_cs   = 0;
assign snd_addr = 0;
assign snd      = 0;
assign sample   = 0;
assign snd_flag = 0;
assign main_stb = 0;
`endif

endmodule