/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Author: Rafael Eduardo Paiva Feener. Copyright: Jose Tejada Gomez
 * Version: 1.0
 * Date: 17-6-2026 */

module jtmoo_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

localparam MOOMESA = 0,
           BUCKY   = 1;

/* verilator tracing_off */
wire        snd_irq, rmrd, rst8, rst_snd, dma_bsy,
            pal_cs, cpu_we, tilesys_cs, objsys_cs, pcu_cs, col_cs, objcha_n,
            cpu_rnw, vdtac, tile_irqn, tile_nmin,
            objreg_cs, scrreg_cs, scr_cs, pair_we, cco_cs, rw, int1,
            blnk_sel, nc;
wire [ 1:0] oram_we;
wire [ 7:0] vtimer_mmr;
wire [15:0] pal_dout, oram_dout;
wire [15:0] video_dumpa;
wire [13:1] oram_addr;
reg  [ 7:0] debug_mux;
// reg  [ 2:0] game_id;
wire [15:0] tilesys_dout;
wire [ 7:0] obj_dout, snd_latch, pair_dout,
            st_main, st_video, st_snd;
// wire [ 1:0] oram_we;
wire [ 3:0] vtimer_addr;
reg         moomesa, bucky;

assign debug_view = debug_mux;
// assign ram_we     = cpu_we & ram_cs;
assign ram_addr   = main_addr[15:1];
assign video_dumpa= ioctl_addr[15:0]-16'h80; // subtract NVRAM offset
assign vtimer_addr= main_addr[4:1];
assign rst_snd    = rst;

always @(posedge clk) begin
    debug_mux <= st_snd;
    // case( debug_bus[7:6] )
    //     0: debug_mux <= st_main;
    //     1: debug_mux <= st_video;
    //     2: debug_mux <= st_snd;
    //     3: debug_mux <= 8'd0;
    //     default: debug_mux <= 0;
    // endcase
end

always @(posedge clk) begin
    if( prog_addr[3:0]==15 && prog_we && header ) begin
        moomesa <= prog_data[MOOMESA];
        bucky   <= prog_data[BUCKY];
    end
end

/* verilator tracing_on */
jtmoo_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen_16         ( cen_16        ),
    .LVBL           ( LVBL          ),
    .bucky          ( bucky         ),
    .int1           ( int1          ),

    .cpu_we         ( cpu_we        ),
    .cpu_dout       ( ram_din       ),
    .vdtac          ( vdtac         ),
    .tile_irqn      ( tile_irqn     ),

    .main_addr      ( main_addr     ),
    .rom_data       ( main_data     ),
    .rom_cs         ( main_cs       ),
    .rom_ok         ( main_ok       ),
    // RAM
    .ram_dsn        ( ram_dsn       ),
    .ram_dout       ( ram_data      ),
    .ram_cs         ( ram_cs        ),
    .ram_ok         ( ram_ok        ),
    .ram_we         ( ram_we        ),

    .cco_cs         ( cco_cs        ),
    .rw             ( rw            ),
    .vtimer_mmr     ( vtimer_mmr    ),
    // cabinet I/O
    .cab_1p         ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .joystick3      ( joystick3     ),
    .joystick4      ( joystick4     ),
    .service        ( {4{service}}  ),

    .vram_dout      ( tilesys_dout  ),
    .oram_dout      ( oram_dout     ),
    .pal_dout       ( pal_dout      ),
    // To video
    .rmrd           ( rmrd          ),
    .dma_bsy        ( dma_bsy       ),
    .objreg_cs      ( objreg_cs     ),
    .scrreg_cs      ( scrreg_cs     ),
    .objcha_n       ( objcha_n      ),
    .blnk_sel       ( blnk_sel      ),

    .oram_we        ( oram_we       ),
    .obj_cs         ( objsys_cs     ),
    .scr_cs         ( scr_cs        ),
    .vram_cs        ( tilesys_cs    ),
    .pal_cs         ( pal_cs        ),
    .pcu_cs         ( pcu_cs        ), // priority mixer
    .col_cs         ( col_cs        ), // K054338 registers
    // To sound
    .sndon          ( snd_irq       ),
    .pair_we        ( pair_we       ),
    .pair_dout      ( pair_dout     ),
    // EEPROM
    .nv_addr        ( nvram_addr    ),
    .nv_dout        ( nvram_dout    ),
    .nv_din         ( nvram_din     ),
    .nv_we          ( nvram_we      ),
    // DIP switches
    .dipsw          ( dipsw[3:0]    ),
    .dip_pause      ( dip_pause     ),
    .dip_test       ( dip_test      ),
    // Debug
    .st_dout        ( st_main       ),
    .debug_bus      ( debug_bus     )
);

// assign oram_we   = ~ram_dsn & {2{cpu_we}};
assign oram_addr = {main_addr[6:5], main_addr[1], main_addr[13:7], main_addr[4:2]};

/* verilator tracing_on */
jtmoo_video u_video (
    .rst            ( rst           ),
    .rst8           ( rst8          ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .pxl2_cen       ( pxl2_cen      ),

    .tile_irqn      ( tile_irqn     ),
    .tile_nmin      (               ),

    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    .flip           ( dip_flip      ),
    // GFX - CPU interface
    .cpu_we         ( cpu_we        ),
    .cpu_addr       (main_addr[16:1]),
    .cpu_dsn        ( ram_dsn       ),
    .cpu_dout       ( ram_din       ),

    // Object DMA
    .oram_we        ( oram_we       ),
    .oram_addr      ( oram_addr     ),
    .dma_bsy        ( dma_bsy       ),

    .objsys_cs      ( objsys_cs     ),
    .objreg_cs      ( objreg_cs     ),
    .objcha_n       ( objcha_n      ),
    .tilesys_cs     ( tilesys_cs    ),
    .scr_cs         ( scr_cs        ),
    .scrreg_cs      ( scrreg_cs     ),
    .blnk_sel       ( blnk_sel      ),
    .pal_cs         ( pal_cs        ),
    .pcu_cs         ( pcu_cs        ),
    .col_cs         ( col_cs        ),
    .vdtac          ( vdtac         ),
    .tilesys_dout   ( tilesys_dout  ),
    .objsys_dout    ( oram_dout     ),
    .pal_dout       ( pal_dout      ),
    .rmrd           ( rmrd          ),

    .int1           ( int1          ),
    .cco_cs         ( cco_cs        ),
    .rw             ( rw            ),
    .vtimer_mmr     ( vtimer_mmr    ),
    .vtimer_addr    ( vtimer_addr   ),
    // SDRAM
    .lyra_addr      ( lyra_addr     ),
    .lyrb_addr      ( lyrb_addr     ),
    .lyrf_addr      ( lyrf_addr     ),
    .lyro_addr      ( lyro_addr     ),
    .lyra_data      ( lyra_data     ),
    .lyrb_data      ( lyrb_data     ),
    .lyro_data      ( lyro_data     ),
    .lyrf_data      ( lyrf_data     ),
    .lyrf_cs        ( lyrf_cs       ),
    .lyra_cs        ( lyra_cs       ),
    .lyrb_cs        ( lyrb_cs       ),
    .lyro_cs        ( lyro_cs       ),
    .lyra_ok        ( lyra_ok       ),
    .lyro_ok        ( lyro_ok       ),
    // brightness
    .dim            (  3'b0         ),
    .dimmod         (  1'b0         ),
    .dimpol         (  1'b0         ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .ioctl_addr     ( video_dumpa   ),
    .ioctl_din      ( ioctl_din     ),
    .ioctl_ram      ( ioctl_ram     ),
    .gfx_en         ( gfx_en        ),
    .st_dout        ( st_video      )
);

/* verilator tracing_on */
// jtrungun_sound now exposes a 17-bit ROM address; Moo's SDRAM port remains 18 bits.
assign snd_addr[17] = 1'b0;

jtrungun_sound #(.PRMR(1)) u_sound(
    .rst            ( rst_snd       ),
    .clk            ( clk           ),
    .cen_8          ( cen_8         ),
    .cen_pcm        ( cen_pcm       ),

    // communication with main CPU
    .main_dout      ( ram_din[7:0]  ),
    .pair_dout      ( pair_dout     ),
    .main_addr      ( main_addr[4:1]),
    .pair_we        ( pair_we       ),

    .snd_irq        ( snd_irq       ),
    // ROM
    .rom_addr       ( snd_addr[16:0]), // Current jtrungun_sound ROM interface is 17 bits wide
    .rom_cs         ( snd_cs        ),
    .rom_data       ( snd_data      ),
    .rom_ok         ( snd_ok        ),
    // ADPCM ROM
    .pcma_addr      ( {nc,pcm_addr} ),
    .pcmb_addr      (               ),
    .pcma_data      ( pcm_data      ),
    .pcmb_data      ( 8'd0          ),
    .pcma_cs        ( pcm_cs        ),
    .pcmb_cs        (               ),
    // Sound output
    .k539_l         ( k539_l        ),
    .k539_r         ( k539_r        ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .st_dout        ( st_snd        )
);

endmodule
