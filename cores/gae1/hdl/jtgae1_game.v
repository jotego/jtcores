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
    Date: 2-7-2026 */

module jtgae1_game(
    `include "jtframe_game_ports.inc"
);

wire        vblank_irq;
wire        flip;
wire [13:0] vmem_addr;
wire        vmem_uds, vmem_lds, vmem_we;
wire        vmem_vram_cs, vmem_scrram_cs, vmem_pal_cs, vmem_spr_cs;
wire [15:0] cpu_vram_rd, cpu_scrram_rd, cpu_pal_rd, cpu_spr_rd;
wire [15:0] scr0_y, scr0_x, scr1_y, scr1_x;
wire [17:0] oki_core_addr;
wire [ 7:0] snd_latch, main_oki_din, sound_oki_din, oki_dout, oki_din;
wire [ 5:0] vram_p1;
wire [ 5:0] spr_force_high;
wire        gfx_4m, vcrypt, snd_irq;
wire        cpu_rst;
wire        vram_odd;
wire        squash, thoop, biomtoy, bigkarnk;
wire        main_oki_wrn, sound_oki_wrn, oki_wrn;
wire [ 3:0] oki_bank;
wire signed [15:0] sound_opl;

assign cpu_rst = rst;
assign opl       = bigkarnk ? sound_opl : 16'sd0;
assign oki_din   = bigkarnk ? sound_oki_din : main_oki_din;
assign oki_wrn   = bigkarnk ? sound_oki_wrn : main_oki_wrn;
assign oki_addr  = bigkarnk || oki_core_addr < 18'h30000
                 ? { 2'b00, oki_core_addr }
                 : { oki_bank, oki_core_addr[15:0] };
assign oki_cs    = 1'b1;

assign vram_odd      = vmem_addr[1];
assign vram_cpu_addr = vmem_addr[12:2];
assign vram_cpu_din  = { vmem_dec_wdata, vmem_dec_wdata };
assign vram_we       = !vmem_we || !vmem_vram_cs ? 4'd0 :
                       vram_odd                  ? { 2'b00, vmem_uds, vmem_lds } :
                                                   { vmem_uds, vmem_lds, 2'b00 };
assign cpu_vram_rd   = vram_odd ? vram0_cpu_dout[15:0] : vram0_cpu_dout[31:16];

assign scrram_cpu_addr = vmem_addr[12:1];
assign scrram_we       = {2{vmem_we & vmem_scrram_cs}} & { vmem_uds, vmem_lds };
assign cpu_scrram_rd   = scrram_cpu_dout;

assign pal_cpu_addr = vmem_addr[10:1];
assign pal_we       = {2{vmem_we & vmem_pal_cs}} & { vmem_uds, vmem_lds };
assign cpu_pal_rd   = pal_cpu_dout;

assign spr_cpu_addr = vmem_addr[11:1];
assign spr_we       = {2{vmem_we & vmem_spr_cs}} & { vmem_uds, vmem_lds };
assign cpu_spr_rd   = spr_cpu_dout;
assign ioctl_din = 8'd0;
assign scrram_addr  = 12'd0;

assign gfx0_cs   = 1'b1;
assign gfx1_cs   = 1'b1;

assign debug_view = { bigkarnk, gfx_4m, vcrypt, spr_force_high[2:1], biomtoy, thoop, squash };
assign dip_flip   = flip;

jtgae1_header u_header (
    .clk              ( clk                ),
    .header           ( header             ),
    .prog_we          ( prog_we            ),
    .squash           ( squash             ),
    .thoop            ( thoop              ),
    .biomtoy          ( biomtoy            ),
    .bigkarnk         ( bigkarnk           ),
    .vcrypt           ( vcrypt             ),
    .vram_p1          ( vram_p1            ),
    .gfx_4m           ( gfx_4m             ),
    .spr_force_high   ( spr_force_high     ),
    .prog_addr        ( prog_addr[2:0]     ),
    .prog_data        ( prog_data          )
);

jtgae1_main u_main (
    .clk               ( clk             ),
    .rst               ( cpu_rst         ),
    .lvbl              ( LVBL            ),
    .bigkarnk          ( bigkarnk        ),
    .vcrypt            ( vcrypt          ),
    .vram_p1           ( vram_p1         ),
    .main_addr         ( main_addr       ),
    .main_cs           ( main_cs         ),
    .main_data         ( main_data       ),
    .main_data_ok      ( main_ok         ),
    .cpu_dout          ( cpu_dout        ),
    .ram_addr          ( ram_addr        ),
    .ram_dsn           ( ram_dsn         ),
    .ram_we            ( ram_we          ),
    .ram_cs            ( ram_cs          ),
    .ram_data          ( ram_data        ),
    .ram_ok            ( ram_ok          ),
    .dipsw             ( dipsw[15:0]     ),
    .joystick1         ( joystick1[5:0]  ),
    .joystick2         ( joystick2[5:0]  ),
    .coin              ( coin[1:0]       ),
    .start             ( cab_1p[1:0]     ),
    .service           ( service         ),
    .dip_test          ( dip_test        ),
    .dip_pause         ( dip_pause       ),
    .flip              ( flip            ),
    .vmem_addr         ( vmem_addr       ),
    .vmem_uds          ( vmem_uds        ),
    .vmem_lds          ( vmem_lds        ),
    .vmem_we           ( vmem_we         ),
    .vmem_vram_cs      ( vmem_vram_cs    ),
    .vmem_scrram_cs    ( vmem_scrram_cs  ),
    .vmem_pal_cs       ( vmem_pal_cs     ),
    .vmem_spr_cs       ( vmem_spr_cs     ),
    .vmem_dec_wdata    ( vmem_dec_wdata  ),
    .vmem_io_wdata     ( vmem_io_wdata   ),
    .vmem_vram_rdata   ( cpu_vram_rd     ),
    .vmem_scrram_rdata ( cpu_scrram_rd   ),
    .vmem_pal_rdata    ( cpu_pal_rd      ),
    .vmem_spr_rdata    ( cpu_spr_rd      ),
    .scr0_y            ( scr0_y          ),
    .scr0_x            ( scr0_x          ),
    .scr1_y            ( scr1_y          ),
    .scr1_x            ( scr1_x          ),
    .oki_din           ( main_oki_din    ),
    .oki_dout          ( oki_dout        ),
    .oki_wrn           ( main_oki_wrn    ),
    .oki_bank          ( oki_bank        ),
    .snd_latch         ( snd_latch       ),
    .snd_irq           ( snd_irq         )
);

jtgae1_sound u_sound (
    .clk       ( clk            ),
    .rst       ( cpu_rst        ),
    .enable    ( bigkarnk       ),
    .cen_snd   ( cen_snd        ),
    .cen_opl   ( cen_opl        ),
    .snd_irq   ( snd_irq        ),
    .snd_latch ( snd_latch      ),
    .rom_addr  ( snd0_addr      ),
    .rom_cs    ( snd0_cs        ),
    .rom_data  ( snd0_data      ),
    .rom_ok    ( snd0_ok        ),
    .oki_din   ( sound_oki_din  ),
    .oki_dout  ( oki_dout       ),
    .oki_wrn   ( sound_oki_wrn  ),
    .opl       ( sound_opl      )
);

jt6295 u_oki (
    .rst      ( rst           ),
    .clk      ( clk           ),
    .cen      ( cen_oki       ),
    .ss       ( 1'b1          ),
    .wrn      ( oki_wrn       ),
    .din      ( oki_din       ),
    .dout     ( oki_dout      ),
    .rom_addr ( oki_core_addr ),
    .rom_data ( oki_data      ),
    .rom_ok   ( oki_ok        ),
    .sound    ( pcm           ),
    .sample   (               )
);

jtgae1_video u_video (
    .clk            ( clk            ),
    .rst            ( rst            ),
    .pxl_cen        ( pxl_cen        ),
    .gfx_en         ( gfx_en         ),
    .gfx_4m         ( gfx_4m         ),
    .squash         ( squash         ),
    .bigkarnk       ( bigkarnk       ),
    .spr_force_high ( spr_force_high ),
    .scr0_y         ( scr0_y         ),
    .scr0_x         ( scr0_x         ),
    .scr1_y         ( scr1_y         ),
    .scr1_x         ( scr1_x         ),
    .tile_a0        ( vram0_addr     ),
    .tile_q0        ( vram0_dout     ),
    .rom_a0         ( gfx0_addr      ),
    .gfx0_data      ( gfx0_data      ),
    .gfx0_ok        ( gfx0_ok        ),
    .tile_a1        ( vram1_addr     ),
    .tile_q1        ( vram1_dout     ),
    .rom_a1         ( gfx1_addr      ),
    .gfx1_data      ( gfx1_data      ),
    .gfx1_ok        ( gfx1_ok        ),
    .scr_pal_addr   ( pal_addr       ),
    .scr_pal_dout   ( pal_dout       ),
    .obj_pal_addr   ( palb_addr      ),
    .obj_pal_dout   ( palb_dout      ),
    .spr_a          ( spr_addr       ),
    .spr_q          ( spr_dout       ),
    .obj_cs         ( obj_cs         ),
    .obj_addr       ( obj_addr       ),
    .obj_data       ( obj_data       ),
    .obj_ok         ( obj_ok         ),
    .red            ( red            ),
    .green          ( green          ),
    .blue           ( blue           ),
    .hsync          ( HS             ),
    .vsync          ( VS             ),
    .lhbl           ( LHBL           ),
    .lvbl           ( LVBL           )
);

endmodule
