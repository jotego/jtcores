// SPDX-License-Identifier: GPL-3.0-or-later

module jtmzone_game(
    `include "jtframe_game_ports.inc"
);

localparam [21:0] OBJ_OFFSET = `OBJ_START >> 1;
localparam [21:0] SCR_OFFSET = `SCR_START >> 1;

wire [10:0] main_shared_addr, snd_shared_addr;
wire [ 7:0] main_shared_din, main_shared_dout;
wire [ 7:0] snd_shared_din, snd_shared_dout;
wire        main_shared_we, snd_shared_we;

// Main/Z80 shared RAM; preload captured contents for scene simulation.
jtframe_dual_ram #(
    .AW(11)
`ifdef SIMSCENE
    ,.SIMFILE("main_shared.bin")
`endif
) u_shared(
    .clk0   ( clk              ),
    .addr0  ( main_shared_addr ),
    .data0  ( main_shared_din  ),
    .we0    ( main_shared_we   ),
    .q0     ( main_shared_dout ),
    .clk1   ( clk              ),
    .addr1  ( snd_shared_addr  ),
    .data1  ( snd_shared_dout  ),
    .we1    ( snd_shared_we    ),
    .q1     ( snd_shared_din   )
);

wire [15:0] main_rom_addr;
wire        main_rom_cs;
wire        main_cpu_rnw;
wire [ 8:0] video_vdump;
wire [ 8:0] video_hdump;
wire [ 8:0] video_vrender;
wire        vram0_cs, vram1_cs, cram0_cs, cram1_cs;
wire [ 9:0] vram_addr;
wire [ 9:0] main_tile_addr;
wire [ 7:0] vram_din;
wire [ 7:0] vram0_dout, vram1_dout, cram0_dout, cram1_dout;
wire [ 9:0] objram_addr;
wire [ 7:0] objram_din;
wire [ 7:0] objram_dout;
wire        objram_cs;
wire [ 7:0] main_scrolly, main_scrollx;
wire        main_flip, intsnd;
// The generic simulation driver does not initialize the optional OSD status
// bits, so keep simulations on the declared 288-pixel default.
wire        dip_orig_hactive =
`ifdef SIMULATION
                                1'b0;
`else
                                status[14];
`endif
`ifdef SIMSCENE
reg  [ 7:0] scene_regs[0:2];
initial begin
    $readmemh("regs.hex", scene_regs);
    $display("MZONE scene registers: scrolly=%02x scrollx=%02x flip=%0d",
        scene_regs[0], scene_regs[1], scene_regs[2][0]);
end
wire [7:0] video_scrolly = scene_regs[0];
wire [7:0] video_scrollx = scene_regs[1];
wire       video_flip    = scene_regs[2][0];
`else
wire [7:0] video_scrolly = main_scrolly;
wire [7:0] video_scrollx = main_scrollx;
wire       video_flip    = main_flip;
`endif
wire        intmain_n;

assign dip_flip   = 0;
`ifndef MZONE_FETCH_DIAG
assign debug_view = 0;
`endif

assign main_addr   = main_rom_addr;
assign main_cs     = main_rom_cs;
assign main_tile_addr = vram_addr;

wire [7:0] main_rom_data = main_data;
wire       main_rom_ok   = main_ok;

`ifdef JTFRAME_LF_BUFFER
assign game_hdump   = video_hdump;
assign game_vrender = video_vrender[7:0];
`endif

`ifdef JTFRAME_IOCTL_RD
assign ioctl_din = 8'hff;
`endif

`ifndef NOMAIN
jtmzone_main u_main(
    .rst        ( rst24          ),
    .clk        ( clk24          ),
    .cpu_clk_cen( cpu4_cen       ),
    .rom_addr   ( main_rom_addr  ),
    .rom_cs     ( main_rom_cs    ),
    .rom_data   ( main_rom_data  ),
    .rom_ok     ( main_rom_ok    ),

    .cpu_rnw    ( main_cpu_rnw   ),
    .vram0_cs   ( vram0_cs   ),
    .vram1_cs   ( vram1_cs   ),
    .cram0_cs   ( cram0_cs   ),
    .cram1_cs   ( cram1_cs   ),
    .shared_addr( main_shared_addr ),
    .shared_dout( main_shared_din  ),
    .shared_we  ( main_shared_we   ),
    .shared_din ( main_shared_dout ),

    .vram_addr( vram_addr  ),
    .vram_din ( vram_din  ),
    .vram0_dout( vram0_dout ),
    .vram1_dout( vram1_dout ),
    .cram0_dout( cram0_dout ),
    .cram1_dout( cram1_dout ),
    .objram_addr( objram_addr ),
    .objram_din ( objram_din  ),
    .objram_cs  ( objram_cs   ),
    .objram_dout( objram_dout ),

    .scrolly    ( main_scrolly   ),
    .scrollx    ( main_scrollx   ),
    .flip       ( main_flip      ),
    .intsnd     ( intsnd         ),

    .LVBL       ( LVBL           ),
    .dip_pause  ( dip_pause      ),
    .intmain_n  ( intmain_n      )
);
`else
assign main_rom_addr   = 16'd0;
assign main_rom_cs     = 1'b0;
assign main_cpu_rnw    = 1'b1;
assign vram0_cs   = 1'b0;
assign vram1_cs   = 1'b0;
assign cram0_cs   = 1'b0;
assign cram1_cs   = 1'b0;
assign main_shared_addr= 11'd0;
assign main_shared_din = 8'd0;
assign main_shared_we  = 1'b0;
assign vram_addr   = 10'd0;
assign vram_din   = 8'd0;
assign objram_addr= 10'd0;
assign objram_din = 8'd0;
assign objram_cs  = 1'b0;
assign main_scrolly    = 8'd0;
assign main_scrollx    = 8'd0;
assign main_flip       = 1'b0;
assign intsnd          = 1'b0;
`endif

jtmzone_snd u_snd(
    .rst        ( rst24          ),
    .clk        ( clk24          ),

    .rom_addr   ( snd_addr       ),
    .rom_cs     ( snd_cs         ),
    .rom_data   ( snd_data       ),
    .rom_ok     ( snd_ok         ),
    .mcu_rom_addr( mcu_rom_addr  ),
    .mcu_rom_cs  ( mcu_rom_cs    ),
    .mcu_rom_data( mcu_rom_data  ),
    .mcu_rom_ok  ( mcu_rom_ok    ),

    .cab_1p     ( cab_1p[1:0]    ),
    .coin       ( coin[1:0]      ),
    .joystick1  ( joystick1[5:0] ),
    .joystick2  ( joystick2[5:0] ),
    .service    ( service        ),
    .dipsw_a    ( dipsw[ 7:0]    ),
    .dipsw_b    ( dipsw[15:8]    ),
    .LVBL       ( LVBL           ),
    .hdump      ( video_hdump    ),
    .shared_addr( snd_shared_addr ),
    .shared_dout( snd_shared_dout ),
    .shared_we  ( snd_shared_we   ),
    .shared_din ( snd_shared_din  ),
    .intsnd     ( intsnd          ),
    .intmain_n  ( intmain_n       ),

    .psg0a       ( psg0a           ),
    .psg0a_rcen  ( psg0a_rcen      ),
    .psg0b       ( psg0b           ),
    .psg0b_rcen  ( psg0b_rcen      ),
    .psg0c       ( psg0c           ),
    .psg0c_rcen  ( psg0c_rcen      ),
    .dac        ( dac            )
);

jtmzone_video u_video(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .clk24      ( clk24          ),
    .pxl_cen    ( pxl_cen        ),

    .main_tile_addr( main_tile_addr ),
    .vram_din ( vram_din  ),
    .main_cpu_rnw  ( main_cpu_rnw   ),
    .vram0_cs ( vram0_cs  ),
    .vram1_cs ( vram1_cs  ),
    .cram0_cs ( cram0_cs  ),
    .cram1_cs ( cram1_cs  ),
    .vram0_dout( vram0_dout ),
    .vram1_dout( vram1_dout ),
    .cram0_dout( cram0_dout ),
    .cram1_dout( cram1_dout ),

    .objram_addr( objram_addr ),
    .objram_din ( objram_din  ),
    .objram_cs  ( objram_cs   ),
    .objram_dout( objram_dout ),

    .scrolly    ( video_scrolly  ),
    .scrollx    ( video_scrollx  ),
    .flip       ( video_flip     ),
    .dip_orig_hactive( dip_orig_hactive ),
    .gfx_en     ( gfx_en         ),
    .prog_data  ( prog_data      ),
    .prog_addr  ( prog_addr      ),
    .prom_we    ( prom_we        ),

    .fixrom_addr( fixrom_addr      ),
    .fixrom_cs  ( fixrom_cs        ),
    .fixrom_data( fixrom_data      ),
    .fixrom_ok  ( fixrom_ok        ),

    .scrrom_addr( scrrom_addr      ),
    .scrrom_cs  ( scrrom_cs        ),
    .scrrom_data( scrrom_data      ),
    .scrrom_ok  ( scrrom_ok        ),
    .obj_addr   ( objrom_addr      ),
    .obj_cs     ( objrom_cs        ),
    .obj_data   ( objrom_data      ),
    .obj_ok     ( objrom_ok        ),

    .HS         ( HS             ),
    .VS         ( VS             ),
    .LHBL       ( LHBL           ),
    .LVBL       ( LVBL           ),
    .red        ( red            ),
    .green      ( green          ),
    .blue       ( blue           ),

    .hdump      ( video_hdump    ),
    .vdump      ( video_vdump    ),
    .vrender    ( video_vrender  )
`ifdef MZONE_FETCH_DIAG
    ,.debug_bus ( debug_bus      )
    ,.fetch_debug( debug_view    )
`endif
);

endmodule
