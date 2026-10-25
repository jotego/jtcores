/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-10-2026 */

module jtsvolle_game(
    `include "jtframe_game_ports.inc"
);

wire [19:1] cpu_addr;
wire [1:0] cpu_dsn;
wire cpu_rnw, snd_wr, snd_pending, irq_event, obj_overrun;
wire [7:0] snd_latch, main_debug;
wire [8:0] scrx0, scry0, scrx1, scry1;
wire [15:0] videoflags;
wire [5:0] obj_count, obj_pri;
wire [31:0] gga_h;
wire [23:0] gga_v;
wire [7:0] irq_control;
wire rpunch;
wire cpu_ram_cs, cpu_ram_we, ram_busy, bitmap_overrun;
wire main_reset = rst || ram_busy;

assign main_addr = cpu_addr[17:1];
assign vram0_addr = cpu_addr[12:1];
assign vram1_addr = cpu_addr[12:1];
assign oram_addr = cpu_addr[11:1];
assign pal_addr = cpu_addr[10:1];
assign dip_flip = 0;
assign st_dout = 0;
assign debug_view = debug_bus[7] ? {obj_overrun,bitmap_overrun,ram_busy,5'd0} : main_debug;
always @* begin
    post_data = ((prog_ba==0 && prog_addr>=(rpunch ? 22'h10000 : 22'h18000) && prog_addr<22'h20000) ||
                 (prog_ba==3 && prog_addr>=(rpunch ? 22'h18000 : 22'h20000) && prog_addr<22'h28000)) ?
                  8'd0 : prog_data;
end

jtsvolle_header u_header(
    .clk        ( clk           ),
    .header     ( header        ),
    .prog_we    ( prog_we       ),
    .prog_addr  ( prog_addr[2:0] ),
    .prog_data  ( prog_data     ),
    .rpunch     ( rpunch        )
);

jtsvolle_main u_main(
    .rst        ( main_reset    ),
    .clk        ( clk           ),
    .dip_pause  ( dip_pause     ),
    .irq_event  ( irq_event     ),
    .rpunch     ( rpunch        ),
    .addr       ( cpu_addr      ),
    .dout       ( main_dout     ),
    .dsn        ( cpu_dsn       ),
    .rnw        ( cpu_rnw       ),
    .rom_cs     ( main_cs       ),
    .work_cs    ( cpu_ram_cs    ),
    .work_we    ( cpu_ram_we    ),
    .rom_data   ( main_data     ),
    .work_data  ( work_data     ),
    .rom_ok     ( main_ok       ),
    .work_ok    ( work_ok       ),
    .vram0_we   ( vram0_we      ),
    .vram1_we   ( vram1_we      ),
    .oram_we    ( oram_we       ),
    .pal_we     ( pal_we        ),
    .vram0_data ( vram0_dout    ),
    .vram1_data ( vram1_dout    ),
    .oram_data  ( oram_dout     ),
    .pal_data   ( pal_dout      ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .coin       ( coin          ),
    .cab_1p     ( cab_1p        ),
    .service    ( service       ),
    .dip_test   ( dip_test      ),
    .dipsw      ( dipsw[15:0]   ),
    .snd_latch  ( snd_latch     ),
    .snd_wr     ( snd_wr        ),
    .snd_pending( snd_pending   ),
    .scrx0      ( scrx0         ),
    .scry0      ( scry0         ),
    .scrx1      ( scrx1         ),
    .scry1      ( scry1         ),
    .videoflags ( videoflags    ),
    .obj_count  ( obj_count     ),
    .obj_pri    ( obj_pri       ),
    .gga_h      ( gga_h         ),
    .gga_v      ( gga_v         ),
    .irq_control( irq_control   ),
    .debug_bus  ( debug_bus     ),
    .debug_view ( main_debug    )
);

jtsvolle_mainram u_mainram(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .rpunch     ( rpunch        ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( main_dout     ),
    .cpu_dsn    ( cpu_dsn       ),
    .cpu_cs     ( cpu_ram_cs    ),
    .cpu_we     ( cpu_ram_we    ),
    .ram_addr   ( work_addr     ),
    .ram_din    ( work_din      ),
    .ram_dsn    ( work_dsn      ),
    .ram_cs     ( work_cs       ),
    .ram_we     ( work_we       ),
    .ram_ok     ( work_ok       ),
    .busy       ( ram_busy      )
);

jtsvolle_video u_video(
    .rst        ( main_reset    ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .rpunch     ( rpunch        ),
    .gga_h      ( gga_h         ),
    .gga_v      ( gga_v         ),
    .irq_control( irq_control   ),
    .scrx0      ( scrx0         ),
    .scry0      ( scry0         ),
    .scrx1      ( scrx1         ),
    .scry1      ( scry1         ),
    .videoflags ( videoflags    ),
    .obj_count  ( obj_count     ),
    .obj_pri    ( obj_pri       ),
    .scrv0_addr ( scrv0_addr    ),
    .scrv1_addr ( scrv1_addr    ),
    .scrv0_data ( scrv0_data    ),
    .scrv1_data ( scrv1_data    ),
    .objr_addr  ( objr_addr     ),
    .objr_data  ( objr_data     ),
    .mix_addr   ( mix_addr      ),
    .mix_data   ( mix_data      ),
    .scr0_addr  ( scr0_addr     ),
    .scr1_addr  ( scr1_addr     ),
    .obj_addr   ( obj_addr      ),
    .scr0_cs    ( scr0_cs       ),
    .scr1_cs    ( scr1_cs       ),
    .obj_cs     ( obj_cs        ),
    .scr0_data  ( scr0_data     ),
    .scr1_data  ( scr1_data     ),
    .obj_data   ( obj_data      ),
    .scr0_ok    ( scr0_ok       ),
    .scr1_ok    ( scr1_ok       ),
    .obj_ok     ( obj_ok        ),
    .bitmap_addr( bitmap_addr   ),
    .bitmap_cs  ( bitmap_cs     ),
    .bitmap_data( bitmap_data   ),
    .bitmap_ok  ( bitmap_ok     ),
    .gfx_en     ( gfx_en        ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .irq_event  ( irq_event     ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .obj_overrun( obj_overrun   ),
    .bmp_overrun( bitmap_overrun )
);

jtsvolle_snd u_sound(
    .rst        ( main_reset    ),
    .clk        ( clk           ),
    .snd_cen    ( snd_cen       ),
    .fm_cen     ( fm_cen        ),
    .fm2_cen    ( fm2_cen       ),
    .pcm_cen    ( pcm_cen       ),
    .latch_data ( snd_latch     ),
    .latch_wr   ( snd_wr        ),
    .pending    ( snd_pending   ),
    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),
    .ram_addr   ( sram_addr     ),
    .ram_din    ( sram_din      ),
    .ram_we     ( sram_we       ),
    .ram_data   ( sram_dout     ),
    .pcm_addr   ( pcm_addr      ),
    .pcm_cs     ( pcm_cs        ),
    .pcm_data   ( pcm_data      ),
    .pcm_ok     ( pcm_ok        ),
    .snd_en     ( snd_en        ),
    .sound      ( snd           ),
    .sample     ( sample        )
);

endmodule
