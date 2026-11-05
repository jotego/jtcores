/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtroller_game(
    `include "jtframe_game_ports.inc"
);

wire [15:0] cpu_addr;
wire [ 7:0] ccu_dout, psac_dout, obj_dout;
wire [ 7:0] snd_dout, st_main, st_video;
wire [ 7:0] video_ioctl;
wire        cpu_we, ccu_cs, ccu_int1, psac_reg_cs, psac_vr_cs;
wire        obj_reg_cs, obj_ram_cs, pal_cs, snd_main_cs, snd_irq;
wire        psac_readroms, psac_wrap, psac_cpu_ok, obj_cpu_ok;
reg  [ 7:0] debug_mux;

assign ram_din    = cpu_dout;
assign pal_we     = cpu_we && pal_cs;
assign debug_view = debug_mux;
assign dip_flip   = ~dipsw[16];
`ifdef JTFRAME_IOCTL_RD
assign ioctl_din  = video_ioctl;
`endif

always @(posedge clk) begin
    case (debug_bus[7:6])
        2'd0: debug_mux <= 0;
        2'd1: debug_mux <= {5'd0,psac_readroms,psac_wrap,ccu_int1};
        2'd2: debug_mux <= st_video;
        2'd3: debug_mux <= st_main;
    endcase
end

jtroller_main u_main(
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen24          ( cen24          ),
    .cpu_addr       ( cpu_addr       ),
    .cpu_dout       ( cpu_dout       ),
    .cpu_we         ( cpu_we         ),
    .main_addr      ( main_addr      ),
    .main_cs        ( main_cs        ),
    .main_data      ( main_data      ),
    .main_ok        ( main_ok        ),
    .ram_we         ( ram_we         ),
    .ram_dout       ( ram_dout       ),
    .cab_1p         ( cab_1p[1:0]    ),
    .coin           ( coin[1:0]      ),
    .joystick1      ( joystick1      ),
    .joystick2      ( joystick2      ),
    .service        ( service        ),
    .dipsw          ( dipsw[23:0]    ),
    .dip_pause      ( dip_pause      ),
    .ccu_int1       ( ccu_int1       ),
    .ccu_dout       ( ccu_dout       ),
    .psac_dout      ( psac_dout      ),
    .psac_rom_data  ( psac_data      ),
    .obj_dout       ( obj_dout       ),
    .pal_dout       ( pal_dout       ),
    .snd_dout       ( snd_dout       ),
    .psac_ok        ( psac_cpu_ok    ),
    .obj_ok         ( obj_cpu_ok     ),
    .ccu_cs         ( ccu_cs         ),
    .psac_reg_cs    ( psac_reg_cs    ),
    .psac_vr_cs     ( psac_vr_cs     ),
    .obj_reg_cs     ( obj_reg_cs     ),
    .obj_ram_cs     ( obj_ram_cs     ),
    .pal_cs         ( pal_cs         ),
    .snd_cs         ( snd_main_cs    ),
    .snd_irq        ( snd_irq        ),
    .psac_readroms  ( psac_readroms  ),
    .psac_wrap      ( psac_wrap      ),
    .st_dout        ( st_main        )
);

jtroller_sound u_sound(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .cen_fm     ( cen_fm     ),
    .cen_pcm    ( cen_pcm    ),
    .snd_irq    ( snd_irq    ),
    .main_cs    ( snd_main_cs),
    .main_we    ( cpu_we     ),
    .main_a0    ( cpu_addr[1]), // C1 (053260) pin 18 is MAIN_A1
    .main_dout  ( cpu_dout   ),
    .main_din   ( snd_dout   ),
    .rom_addr   ( snd_addr   ),
    .rom_cs     ( snd_cs     ),
    .rom_data   ( snd_data   ),
    .rom_ok     ( snd_ok     ),
    .pcma_addr  ( pcma_addr  ),
    .pcmb_addr  ( pcmb_addr  ),
    .pcmc_addr  ( pcmc_addr  ),
    .pcmd_addr  ( pcmd_addr  ),
    .pcma_cs    ( pcma_cs    ),
    .pcmb_cs    ( pcmb_cs    ),
    .pcmc_cs    ( pcmc_cs    ),
    .pcmd_cs    ( pcmd_cs    ),
    .pcma_data  ( pcma_data  ),
    .pcmb_data  ( pcmb_data  ),
    .pcmc_data  ( pcmc_data  ),
    .pcmd_data  ( pcmd_data  ),
    .pcma_ok    ( pcma_ok    ),
    .pcmb_ok    ( pcmb_ok    ),
    .pcmc_ok    ( pcmc_ok    ),
    .pcmd_ok    ( pcmd_ok    ),
    .fm         ( fm         ),
    .pcm_l      ( pcm_l      ),
    .pcm_r      ( pcm_r      ),
    .snd_en     ( snd_en     )
);

jtroller_video u_video(
    .rst            ( rst            ),
    .clk            ( clk            ),
    .pxl_cen        ( pxl_cen        ),
    .pxl2_cen       ( pxl2_cen       ),
    .cen24          ( cen24          ),
    .lhbl           ( LHBL           ),
    .lvbl           ( LVBL           ),
    .hs             ( HS             ),
    .vs             ( VS             ),
    .ccu_int1       ( ccu_int1       ),
    .cpu_addr       ( cpu_addr       ),
    .cpu_dout       ( cpu_dout       ),
    .cpu_we         ( cpu_we         ),
    .ccu_cs         ( ccu_cs         ),
    .psac_reg_cs    ( psac_reg_cs    ),
    .psac_vr_cs     ( psac_vr_cs     ),
    .obj_reg_cs     ( obj_reg_cs     ),
    .obj_ram_cs     ( obj_ram_cs     ),
    .psac_readroms  ( psac_readroms  ),
    .psac_wrap      ( psac_wrap      ),
    .ccu_dout       ( ccu_dout       ),
    .psac_dout      ( psac_dout      ),
    .obj_dout       ( obj_dout       ),
    .psac_cpu_ok    ( psac_cpu_ok    ),
    .obj_cpu_ok     ( obj_cpu_ok     ),
    .psac_addr      ( psac_addr      ),
    .psac_cs        ( psac_cs        ),
    .psac_data      ( psac_data      ),
    .psac_ok        ( psac_ok        ),
    .obj_addr       ( obj_addr       ),
    .obj_cs         ( obj_cs         ),
    .obj_data       ( obj_data       ),
    .obj_ok         ( obj_ok         ),
    .red            ( red            ),
    .green          ( green          ),
    .blue           ( blue           ),
    .palrd_addr     ( palrd_addr     ),
    .pal_data       ( pal_data       ),
    .ioctl_addr     ( ioctl_addr[14:0]),
    .ioctl_ram      ( ioctl_ram      ),
    .ioctl_din      ( video_ioctl    ),
    .gfx_en         ( gfx_en         ),
    .debug_bus      ( debug_bus      ),
    .st_dout        ( st_video       )
);

endmodule
