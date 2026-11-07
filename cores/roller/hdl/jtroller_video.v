/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtroller_video(
    input             rst, clk, pxl_cen, pxl2_cen, cen24,
    output            lhbl, lvbl, hs, vs,
    output            ccu_int1,
    input      [15:0] cpu_addr,
    input      [ 7:0] cpu_dout,
    input             cpu_we,
    input             ccu_cs, psac_reg_cs, psac_vr_cs,
                      obj_reg_cs, obj_ram_cs,
                      psac_readroms, psac_wrap,
    output     [ 7:0] ccu_dout, psac_dout, obj_dout,
    output            psac_cpu_ok, obj_cpu_ok,
    output     [18:0] psac_addr,
    output            psac_cs,
    input      [ 7:0] psac_data,
    input             psac_ok,
    output     [20:2] obj_addr,
    output            obj_cs,
    input      [31:0] obj_data,
    input             obj_ok,
    output     [ 4:0] red, green, blue,
    output     [10:0] palrd_addr,
    input      [ 7:0] pal_data,
    input      [14:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din,
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [23:0] psac_full_addr;
wire [21:2] obj_full_addr;
wire [15:0] obj_word;
wire [ 8:0] hdump, vdump, vrender, obj_pxl;
wire [ 7:0] psac_pxl, psac_dump, obj_dump, ccu_dump;
wire [ 7:0] psac_mmr, obj_mmr;
wire [ 4:0] obj_prio;
wire [ 1:0] obj_we;
wire        hld, vld, psac_opaque, obj_shadow, obj_dma_bsy;
wire        obj_half;

assign psac_addr = psac_full_addr[18:0];
assign obj_addr  = obj_full_addr[20:2];
assign obj_half  = cpu_addr[0];
assign obj_we    = {obj_ram_cs && cpu_we && !obj_half,
                    obj_ram_cs && cpu_we &&  obj_half};
assign st_dout   = {obj_dma_bsy,psac_readroms,psac_wrap,
                    obj_prio};
assign ioctl_din = ioctl_addr[12:11]==1 ? psac_dump :
                   ioctl_addr[12:11]==2 ? obj_dump  :
                   ioctl_addr[4]       ? psac_mmr  :
                   ioctl_addr[3]       ? obj_mmr   : ccu_dump;

assign obj_dout = obj_reg_cs && !cpu_we && cpu_addr[3:2]==2'b11 ? obj_word[7:0] :
                  obj_half ? obj_word[7:0] : obj_word[15:8];

jtk053252 u_ccu(
    .rst        ( rst                 ),
    .clk        ( clk                 ),
    .pxl_cen    ( pxl_cen             ),
    .sel        ( 3'd0                ),
    .vldi       ( 1'b1                ),
    .hldi       ( 1'b1                ),
    .cs         ( ccu_cs              ),
    .addr       ( cpu_addr[3:0]       ),
    .rnw        ( ~cpu_we             ),
    .din        ( cpu_dout            ),
    .dout       ( ccu_dout            ),
    .lhbl       ( lhbl                ),
    .lvbl       ( lvbl                ),
    .hs         ( hs                  ),
    .vs         ( vs                  ),
    .int1       ( ccu_int1            ),
    .int2       (                     ),
    .hld        ( hld                 ),
    .vld        ( vld                 ),
    .lhbs       (                     ),
    .ioctl_addr ( ioctl_addr[3:0]     ),
    .ioctl_din  ( ccu_dump            )
);

jtroller_vtimer u_vtimer(
    .rst      ( rst     ),
    .clk      ( clk     ),
    .pxl_cen  ( pxl_cen ),
    .hld      ( hld     ),
    .vld      ( vld     ),
    .hdump    ( hdump   ),
    .vdump    ( vdump   ),
    .vrender  ( vrender )
);

// The GX999 zoom output starts eight pixels earlier than GX861.
jt051316 #(
    .BPP(4),.ROLLERG(1),.RD_DLY(9'h003),.WR_STRT(9'h058)
) u_psac(
    .rst        ( rst                 ),
    .clk        ( clk                 ),
    .pxl_cen    ( pxl_cen             ),
    .cen24      ( cen24               ),
    .hs         ( hs                  ),
    .vs         ( vs                  ),
    .lhbl       ( lhbl                ),
    .lvbl       ( lvbl                ),
    .cpu_addr   ( cpu_addr[10:0]      ),
    .cpu_dout   ( cpu_dout            ),
    .cpu_din    ( psac_dout           ),
    .cpu_ok     ( psac_cpu_ok         ),
    .cpu_we     ( cpu_we              ),
    .io_cs      ( psac_reg_cs         ),
    .vr_cs      ( psac_vr_cs          ),
    .pxl        ( psac_pxl            ),
    .blnk_n     ( psac_opaque         ),
    .rvo        ( 1'b0                ),
    .wrap       ( psac_wrap           ),
    .hdump      ( hdump               ),
    .vdump      ( vdump               ),
    .rom_addr   ( psac_full_addr      ),
    .rom_cs     ( psac_cs             ),
    .rom_ok     ( psac_ok             ),
    .rom_data   ( psac_data           ),
    .ioctl_addr ( ioctl_addr[10:0]    ),
    .ioctl_ram  ( ioctl_ram           ),
    .ioctl_din  ( psac_dump           ),
    .mmr_dump   ( psac_mmr            )
);

// GX999 uses different sprite origins when the 053244 global flip bits are set.
jtriders_obj #(
    .RAMW(10),.CPU_ROM_REG(1),.CPU_8BIT(1),
    .SHADOW(1),.DEBUG_FLICKER(0),
    .HFLIP_OFFSET(10'h12a),.VFLIP_OFFSET(2)
) u_obj(
    .rst        ( rst                ),
    .clk        ( clk                ),
    .pxl_cen    ( pxl_cen            ),
    .pxl2_cen   ( pxl2_cen           ),
    .hdump      ( hdump+9'h020       ),
    .vdump      ( vdump              ),
    .hs         ( hs                 ),
    .lvbl       ( lvbl               ),
    .lgtnfght  ( 1'b0               ),
    .ram_cs     ( obj_ram_cs         ),
    .reg_cs     ( obj_reg_cs         ),
    .mmr_we     ( cpu_we             ),
    .mmr_addr   ( cpu_addr[3:0]      ),
    .mmr_din    ( {cpu_dout,cpu_dout}),
    .mmr_dsn    ( 2'b11              ),
    .mmr_noa1  ( 1'b0               ),
    .ram_din    ( {cpu_dout,cpu_dout}),
    .ram_we     ( obj_we             ),
    .ram_addr   ( cpu_addr[10:1]     ),
    .cpu_din    ( obj_word           ),
    .cpu_ok     ( obj_cpu_ok         ),
    .dma_bsy    ( obj_dma_bsy        ),
    .rom_addr   ( obj_full_addr     ),
    .rom_data   ( obj_data           ),
    .rom_cs     ( obj_cs            ),
    .rom_ok     ( obj_ok             ),
    .objcha_n   ( 1'b1               ),
    .shd        ( obj_shadow         ),
    .prio       ( obj_prio           ),
    .pxl        ( obj_pxl            ),
    .gfx_en     ( 4'hf               ),
    .ioctl_ram  ( ioctl_ram          ),
    .ioctl_addr ( ioctl_addr[13:0]   ),
    .dump_ram   ( obj_dump           ),
    .dump_reg   ( obj_mmr            ),
    .debug_bus  ( debug_bus          )
);

jtroller_colmix u_colmix(
    .rst         ( rst             ),
    .clk         ( clk             ),
    .pxl_cen     ( pxl_cen         ),
    .lhbl        ( lhbl            ),
    .lvbl        ( lvbl            ),
    .psac_pxl    ( psac_pxl        ),
    .psac_opaque ( psac_opaque     ),
    .obj_pxl     ( obj_pxl         ),
    .shadow      ( obj_shadow      ),
    .red         ( red             ),
    .green       ( green           ),
    .blue        ( blue            ),
    .pal_addr    ( palrd_addr      ),
    .pal_data    ( pal_data        ),
    .gfx_en      ( gfx_en          )
);

endmodule
