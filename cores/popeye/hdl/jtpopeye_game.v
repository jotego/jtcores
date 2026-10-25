/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

module jtpopeye_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

`ifdef NOMAIN
localparam SCENE_WRITE = 1'b0;
`else
localparam SCENE_WRITE = 1'b1;
`endif

wire live_rv, scene_rv;
wire [7:0] scene_debug;
wire [12:0] ad;
wire [10:0] dma_addr;
wire [ 7:0] ay_dout, prot_dout, dm, blprot_addr, blprot_data;
wire [ 3:0] dmcs_n;
wire        reset_n, busrq_n, busak_n, dma_cs, rohvs, rohvck,
            csv, csbw_n, dwrbk_n, memwr0, bdir, bc1,
            prot_cs, prot_we, prot_addr,
            vb, hbd_n, ai_n, bi_n, initeo, rv, narrow,
            tpp1rom, boot, tpp1ram, nibd7, tnx1;
wire [ 3:0] sw1;
wire [ 7:0] sw2;
wire [ 1:0] cpyr;
wire [ 1:0] deflicker;
wire [ 5:0] hpos;
wire [ 4:0] vpos;

`ifdef NOMAIN
assign rv = scene_rv;
`else
assign rv = live_rv;
`endif
assign dip_flip     = rv;
assign sw1          = dipsw[3:0];
assign sw2          = dipsw[11:4];
assign cpyr         = dipsw[13:12];
assign deflicker    = status[14:13];
assign narrow       = status[18];
assign vpos         = status[23:19];
assign hpos         = status[29:24];
assign blprotl_addr = blprot_addr;
assign blproth_addr = blprot_addr;
assign blprot_data  = { blproth_data, blprotl_data };
assign debug_view   = scene_debug;
assign psga_rcen    = ~tnx1;
// AY port B is the only video register outside CPU-visible RAM.  Mirror its
// latch for ioctl capture; scene mode freezes the restored copy.
jtpopeye_scene_mmr u_scene(
    .rst(rst), .clk(clk), .cs(SCENE_WRITE), .addr(2'd0), .rnw(1'b0),
    .din({7'd0,live_rv}), .rv(scene_rv),
    .ioctl_addr(ioctl_addr[1:0]), .ioctl_din(ioctl_din),
    .debug_bus(debug_bus), .st_dout(scene_debug)
);

jtpopeye_header u_header(
    .clk        ( clk            ),
    .header     ( header         ),
    .prog_we    ( prog_we        ),
    .prog_addr  ( prog_addr[2:0] ),
    .prog_data  ( prog_data      ),
    .tpp1rom    ( tpp1rom        ),
    .boot       ( boot           ),
    .tpp1ram    ( tpp1ram        ),
    .nibd7      ( nibd7          ),
    .tnx1       ( tnx1           )
);

jtpopeye_main u_main(
    .work_addr     ( work_addr     ),
    .work_we       ( work_we       ),
    .work_dout     ( work_dout     ),
    .rst         ( rst             ),
    .clk         ( clk             ),
    .cpu_cen     ( cpu_cen         ),
    .psg_cen     ( psg_cen         ),
    .vb          ( vb              ),
    .initeo      ( initeo          ),
    .tpp1rom     ( tpp1rom         ),
    .boot        ( boot            ),
    .tpp1ram     ( tpp1ram         ),
    .tnx1        ( tnx1            ),
    .reset_n     ( reset_n         ),
    .cab_1p      ( cab_1p[1:0]     ),
    .coin        ( coin[0]         ),
    .service     ( service         ),
    .dip_pause   ( dip_pause       ),
    .joystick1   ( joystick1[5:0]  ),
    .joystick2   ( joystick2[5:0]  ),
    .busrq_n     ( busrq_n         ),
    .busak_n     ( busak_n         ),
    .dma_cs      ( dma_cs          ),
    .dma_addr    ( dma_addr        ),
    .ad          ( ad              ),
    .dd          ( dd              ),
    .cpu_dout    ( cpu_dout        ),
    .csv         ( csv             ),
    .csbw_n      ( csbw_n          ),
    .dwrbk_n     ( dwrbk_n         ),
    .memwr0      ( memwr0          ),
    .bdir        ( bdir            ),
    .bc1         ( bc1             ),
    .ay_dout     ( ay_dout         ),
    .prot_cs     ( prot_cs         ),
    .prot_we     ( prot_we         ),
    .prot_addr   ( prot_addr       ),
    .prot_dout   ( prot_dout       ),
    .blprot_addr ( blprot_addr     ),
    .blprot_data ( blprot_data     ),
    .main_cs     ( main_cs         ),
    .main_addr   ( main_addr       ),
    .main_data   ( main_data       ),
    .main_ok     ( main_ok         )
);

jtpopeye_prot u_prot(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .reset_n    ( reset_n   ),
    .cs         ( prot_cs   ),
    .we         ( prot_we   ),
    .addr       ( prot_addr ),
    .din        ( cpu_dout  ),
    .dout       ( prot_dout )
);

jtpopeye_dma u_dma(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .reset_n    ( reset_n   ),
    .ai_n       ( ai_n      ),
    .bi_n       ( bi_n      ),
    .hbd_n      ( hbd_n     ),
    .vb         ( vb        ),
    .busak_n    ( busak_n   ),
    .busrq_n    ( busrq_n   ),
    .dma_cs     ( dma_cs    ),
    .dma_addr   ( dma_addr  ),
    .dm         ( dm        ),
    .dmcs_n     ( dmcs_n    ),
    .rohvs      ( rohvs     ),
    .rohvck     ( rohvck    )
);

jtpopeye_video u_video(
    .text_addr     ( text_addr     ),
    .text_cpu_addr ( text_cpu_addr ),
    .text_we       ( text_we       ),
    .color_we      ( color_we      ),
    .text_dout     ( text_dout     ),
    .color_dout    ( color_dout    ),
    .bg_addr       ( bg_addr       ),
    .bglo_we       ( bglo_we       ),
    .bghi_we       ( bghi_we       ),
    .bglo_dout     ( bglo_dout     ),
    .bghi_dout     ( bghi_dout     ),
    .rst          ( rst          ),
    .clk          ( clk          ),
    .cen20        ( cen20        ),
    .cen10        ( cen10        ),
    .cen5         ( cen5         ),
    .pxl2_cen     ( pxl2_cen     ),
    .pxl_cen      ( pxl_cen      ),
    .rv           ( rv           ),
    .ad           ( ad           ),
    .dd           ( dd           ),
    .csv          ( csv          ),
    .csbw_n       ( csbw_n       ),
    .dwrbk_n      ( dwrbk_n      ),
    .memwr0       ( memwr0       ),
    .dm           ( dm           ),
    .dmcs_n       ( dmcs_n       ),
    .rohvs        ( rohvs        ),
    .rohvck       ( rohvck       ),
    .vb           ( vb           ),
    .hbd_n        ( hbd_n        ),
    .ai_n         ( ai_n         ),
    .bi_n         ( bi_n         ),
    .initeo       ( initeo       ),
    .tprom_addr   ( tprom_addr   ),
    .tprom_data   ( tprom_data   ),
    .char_addr    ( char_addr    ),
    .char_data    ( char_data    ),
    .obj0_addr    ( obj0_addr    ),
    .obj0_data    ( obj0_data    ),
    .obj1_addr    ( obj1_addr    ),
    .obj1_data    ( obj1_data    ),
    .obj2_addr    ( obj2_addr    ),
    .obj2_data    ( obj2_data    ),
    .obj3_addr    ( obj3_addr    ),
    .obj3_data    ( obj3_data    ),
    .txtpal_addr  ( txtpal_addr  ),
    .txtpal_data  ( txtpal_data  ),
    .bgpal_addr   ( bgpal_addr   ),
    .bgpal_data   ( bgpal_data   ),
    .objpall_addr ( objpall_addr ),
    .objpall_data ( objpall_data ),
    .objpalh_addr ( objpalh_addr ),
    .objpalh_data ( objpalh_data ),
    .gfx_en       ( gfx_en       ),
    .nibd7        ( nibd7        ),
    .boot         ( boot         ),
    .tnx1         ( tnx1         ),
    .deflicker    ( deflicker    ),
    .narrow       ( narrow       ),
    .hpos         ( hpos         ),
    .vpos         ( vpos         ),
    .HS           ( HS           ),
    .VS           ( VS           ),
    .LHBL         ( LHBL         ),
    .LVBL         ( LVBL         ),
    .red          ( red          ),
    .green        ( green        ),
    .blue         ( blue         ),
    .split_r      ( split_r      ),
    .split_g      ( split_g      ),
    .split_b      ( split_b      ),
    .split_hs     ( split_hs     ),
    .split_vs     ( split_vs     ),
    .split_de     ( split_de     ),
    .split_ce     ( split_ce     ),
    .split_field  ( split_field  )
);

jtpopeye_sound u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .psg_cen    ( psg_cen   ),
    .reset_n    ( reset_n   ),
    .bdir       ( bdir      ),
    .bc1        ( bc1       ),
    .din        ( cpu_dout  ),
    .dout       ( ay_dout   ),
    .sw1        ( sw1       ),
    .sw2        ( sw2       ),
    .cpyr       ( cpyr      ),
    .rv         ( live_rv   ),
    .psga       ( psga      ),
    .psgb       ( psgb      ),
    .psgc       ( psgc      )
);

endmodule
