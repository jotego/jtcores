/*  jtddribble_game.v — Double Dribble (Konami GX690) top-level
    Wires the main/sub/sound MC6809Es, the video pipeline (jtddribble_video),
    and the shared-SRAM / palette BRAMs.
    GPL3 — see jtcores LICENSE
*/

module jtddribble_game(
    `include "jtframe_game_ports.inc"
);

assign dip_flip   = 0;
assign debug_view = 0;

// ---------------------------------------------------------------------------
// Internal wires between sub-modules
// ---------------------------------------------------------------------------
wire [15:0] main_A;           // raw 16-bit address from main CPU
wire        main_rnw;         // 1 = read, 0 = write
wire [ 7:0] main_dout;        // CPU data output

// Per-region chip-selects from main. VRAM/sprite selects are folded into
// k5885_1_cs / k5885_2_cs (each 005885 owns its private SRAM).
wire        pal_cs, shared_cs;
wire        k5885_1_cs, k5885_2_cs;
wire [ 7:0] k5885_1_dout, k5885_2_dout;
wire [ 2:0] main_bank;

// ---------------------------------------------------------------------------
// Main CPU sub-module
// ---------------------------------------------------------------------------
jtddribble_main u_main(
    .rst         ( rst24      ),
    .clk         ( clk24      ),
    .cen         ( cpu_cen    ),
    .cpu_cen     (            ),     // Q-phase strobe, unused
    // ROM
    .rom_addr    ( main_addr  ),
    .rom_cs      ( main_cs    ),
    .rom_data    ( main_data  ),
    .rom_ok      ( main_ok    ),
    // CPU bus exposed for downstream decoders
    .A           ( main_A     ),
    .cpu_rnw     ( main_rnw   ),
    .cpu_dout    ( main_dout  ),
    // Chip-selects (outputs from main)
    .pal_cs       ( pal_cs       ),     // 007327 palette
    .shared_cs    ( shared_cs    ),     // 0x4000-0x5FFF main↔sub shared
    .k5885_1_cs   ( k5885_1_cs   ),     // 005885 #1 (regs 0x0000-0x0004 + VRAM 0x2000-0x3FFF)
    .k5885_2_cs   ( k5885_2_cs   ),     // 005885 #2 (regs 0x0800-0x0804 + VRAM 0x6000-0x7FFF)
    // Data back to CPU
    .pal_dout     ( pal_dout       ),
    .shared_dout  ( shared_ms_dout ),
    .k5885_1_dout ( k5885_1_dout   ),
    .k5885_2_dout ( k5885_2_dout   ),
    .bank_out     ( main_bank      ),     // 0x8000 bank latch
    // chip 1 interrupts fan to both CPUs (NFIR↔IRQ / NIRQ↔FIRQ swap)
    .cpu_irqn    ( k5885_1_fir_n ),
    .cpu_nmin    ( k5885_1_nmi_n ),
    .cpu_firqn   ( k5885_1_irq_n )
);

// ---------------------------------------------------------------------------
// Sub CPU sub-module
// ---------------------------------------------------------------------------
wire [15:0] sub_A;                       // sub CPU address bus
wire [ 7:0] sub_dout;
wire        sub_rnw;
wire        sub_shared_ms_cs, sub_shared_sa_cs;
wire [ 1:0] sub_coin_counter;

// Sub CPU — also the I/O board (assembles + reads the control ports)
jtddribble_sub u_sub(
    .rst            ( rst24      ),
    .clk            ( clk24      ),
    .cen            ( cpu_cen    ),
    .cpu_cen        (            ),
    .rom_addr       ( sub_addr   ),
    .rom_cs         ( sub_cs     ),
    .rom_data       ( sub_data   ),
    .rom_ok         ( sub_ok     ),
    .A              ( sub_A             ),
    .cpu_rnw        ( sub_rnw           ),
    .cpu_dout       ( sub_dout          ),
    .shared_ms_cs   ( sub_shared_ms_cs  ),
    .shared_sa_cs   ( sub_shared_sa_cs  ),
    .shared_ms_dout ( shared_ms_b_dout  ),
    .shared_sa_dout ( shared_sa_dout    ),     // sub↔sound link
    .joystick1      ( joystick1    ),
    .joystick2      ( joystick2    ),
    .cab_1p         ( cab_1p       ),
    .coin           ( coin         ),
    .service        ( service      ),
    .dipsw          ( dipsw        ),
    .coin_counter   ( sub_coin_counter ),
    // chip 1 fans the same interrupts to both CPUs (NFIR↔IRQ / NIRQ↔FIRQ swap)
    .cpu_irqn       ( k5885_1_fir_n ),
    .cpu_nmin       ( k5885_1_nmi_n ),
    .cpu_firqn      ( k5885_1_irq_n )
);

// ---------------------------------------------------------------------------
// MAIN <-> SUB shared SRAM (mem.yaml 'shared_ms' dual-port BRAM)
// ---------------------------------------------------------------------------
// Side A — main CPU (0x4000-0x5FFF → BRAM 0x0-0x1FFF)
assign shared_ms_addr = main_A[12:0];
assign shared_ms_din  = main_dout;
assign shared_ms_we   = shared_cs && !main_rnw;

// Side B — sub CPU (0x0000-0x1FFF)
assign shared_ms_b_addr = sub_A[12:0];
assign shared_ms_b_din  = sub_dout;
assign shared_ms_b_we   = sub_shared_ms_cs && !sub_rnw;

// ---------------------------------------------------------------------------
// Palette RAM — mem.yaml `pal` BRAM (128 B)
// ---------------------------------------------------------------------------
assign pal_addr    = main_A[6:0];
assign pal_din     = main_dout;
assign pal_we      = pal_cs && !main_rnw;

// ---------------------------------------------------------------------------
// Video pipeline (2x 005885 + VRAM BRAMs + colmix; drives RGB/sync)
// ---------------------------------------------------------------------------
wire        k5885_1_irq_n, k5885_1_nmi_n, k5885_1_fir_n;
wire [15:0] k5885_1_R,    k5885_2_R;
wire        k5885_1_RA16, k5885_1_RA17, k5885_1_rom_cs;
wire        k5885_2_RA16, k5885_2_RA17, k5885_2_rom_cs;

jtddribble_video u_video(
    .rst            ( rst            ),
    .clk            ( clk            ),
    .pxl_cen        ( pxl_cen        ),
    .pxl2_cen       ( pxl2_cen       ),
    .cpu_cen        ( cpu_cen        ),
    // CPU bus
    .main_A         ( main_A         ),
    .main_dout      ( main_dout      ),
    .main_rnw       ( main_rnw       ),
    .k5885_1_cs     ( k5885_1_cs     ),
    .k5885_2_cs     ( k5885_2_cs     ),
    .k5885_1_dout   ( k5885_1_dout   ),
    .k5885_2_dout   ( k5885_2_dout   ),
    // gfx ROM
    .k5885_1_R      ( k5885_1_R      ),
    .k5885_1_RA16   ( k5885_1_RA16   ),
    .k5885_1_RA17   ( k5885_1_RA17   ),
    .k5885_1_rom_cs ( k5885_1_rom_cs ),
    .gfx1_data      ( gfx1_data      ),
    .gfx1_ok        ( gfx1_ok        ),
    .k5885_2_R      ( k5885_2_R      ),
    .k5885_2_RA16   ( k5885_2_RA16   ),
    .k5885_2_RA17   ( k5885_2_RA17   ),
    .k5885_2_rom_cs ( k5885_2_rom_cs ),
    .gfx2_data      ( gfx2_data      ),
    .gfx2_ok        ( gfx2_ok        ),
    // interrupts (chip 1 fans to both CPUs)
    .k5885_1_fir_n   ( k5885_1_fir_n   ),
    .k5885_1_irq_n   ( k5885_1_irq_n   ),
    .k5885_1_nmi_n   ( k5885_1_nmi_n   ),
    // video sync
    .LHBL           ( LHBL           ),
    .LVBL           ( LVBL           ),
    .HS             ( HS             ),
    .VS             ( VS             ),
    // palette read port
    .pal_v_addr     ( pal_v_addr     ),
    .pal_v_dout     ( pal_v_dout     ),
    // chip VRAM (mem.yaml vram1/vram2 dual-port BRAMs)
    .vram1_cpu_addr ( vram1_addr     ),
    .vram1_cpu_din  ( vram1_din      ),
    .vram1_cpu_we   ( vram1_we       ),
    .vram1_cpu_dout ( vram1_dout     ),
    .vram1_scn_addr ( vram1_scn_addr ),
    .vram1_scn_dout ( vram1_scn_dout ),
    .vram2_cpu_addr ( vram2_addr     ),
    .vram2_cpu_din  ( vram2_din      ),
    .vram2_cpu_we   ( vram2_we       ),
    .vram2_cpu_dout ( vram2_dout     ),
    .vram2_scn_addr ( vram2_scn_addr ),
    .vram2_scn_dout ( vram2_scn_dout ),
    // RGB out
    .red            ( red            ),
    .green          ( green          ),
    .blue           ( blue           ),
    // sprite-lookup PROM load
    .prog_addr      ( prog_addr[8:0] ),
    .prog_data      ( prog_data[3:0] ),
    .prom_we        ( prom_we        ),
    .debug_bus      ( debug_bus      ),
    .gfx_en         ( gfx_en         )
);

// ---------------------------------------------------------------------------
// SDRAM gfx ROM routing — chip R/RA16/RA17 → gfx{1,2} word address
// ---------------------------------------------------------------------------
// gfx1: 256 KB (64K x 32-bit words) -> 16-bit address. RA16/RA17 stay 0 on chip 1.
assign gfx1_addr = k5885_1_R;
assign gfx1_cs   = k5885_1_rom_cs;

// gfx2: 512 KB (128K x 32-bit words) -> 17-bit address {RA16,R}. RA17 stays 0.
assign gfx2_addr = { k5885_2_RA16, k5885_2_R };
assign gfx2_cs   = k5885_2_rom_cs;

// ---------------------------------------------------------------------------
// SUB <-> SOUND shared SRAM (mem.yaml 'shared_sa' dual-port BRAM, 2 KB)
// ---------------------------------------------------------------------------
// Side A — sub CPU (0x2000-0x27FF)
assign shared_sa_addr = sub_A[10:0];
assign shared_sa_din  = sub_dout;
assign shared_sa_we   = sub_shared_sa_cs && !sub_rnw;

// Side B — sound CPU (0x0000-0x07FF)
assign shared_sa_b_addr = sound_A[10:0];
assign shared_sa_b_din  = sound_dout;
assign shared_sa_b_we   = sound_shared_cs && !sound_rnw;


// ---------------------------------------------------------------------------
// Sound CPU sub-module
// ---------------------------------------------------------------------------
wire [15:0] sound_A;                     // sound CPU address bus
wire [ 7:0] sound_dout;
wire        sound_rnw;
wire        sound_shared_cs, sound_ym_cs;

jtddribble_sound u_sound(
    .rst         ( rst24      ),
    .clk         ( clk24      ),
    .cen         ( sndcpu_cen ),     // snd-gated cen
    .cpu_cen     (            ),
    .rom_addr    ( snd_addr   ),
    .rom_cs      ( snd_cs     ),
    .rom_data    ( snd_data   ),
    .rom_ok      ( snd_ok     ),
    .A           ( sound_A    ),    
    .cpu_rnw     ( sound_rnw  ),
    .cpu_dout    ( sound_dout ),
    .shared_cs   ( sound_shared_cs ),
    .ym_cs       ( sound_ym_cs ),
    .vlm_cs      ( vlm_cs     ),
    .shared_dout ( shared_sa_b_dout ),
    .ym_cen      ( ym_cen     ),
    .vlm_cen     ( vlm_cen    ),
    .HS          ( HS         ),        // sound-IRQ scanline clock (NSYNC)
    .VS          ( VS         ),        // sound-IRQ counter reset (NVSYNC)
    .vlm_addr    ( vlm_addr   ),
    .vlm_data    ( vlm_data   ),
    .vlm_ok      ( vlm_ok     ),
    .fm_snd      ( fm         ),
    .psga        ( psga       ),
    .psgb        ( psgb       ),
    .psgc        ( psgc       ),
    .psga_rcen   ( psga_rcen  ),
    .psgb_rcen   ( psgb_rcen  ),
    .psgc_rcen   ( psgc_rcen  ),
    .vlm_snd     ( vlm        )
);

endmodule