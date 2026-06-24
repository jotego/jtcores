/*  jtddribble_video.v — Video pipeline for Double Dribble (Konami GX690)

    Per jtcores convention this "_video" module is the video PIPELINE: it holds
    the two Konami 005885 graphics generators (E16 = FG, H16 = BG). Their 8 KB
    6264SL VRAMs are mem.yaml dual-port BRAMs (vram1/vram2); this module exposes
    each chip's VRAM ports up to game.v, which wires them to those BRAMs. The
    colour side (007327 palette + LS157 priority mux + sync) is jtddribble_colmix.v.
    jtddribble_game.v instantiates this module and the colmix module.

    The CPU never reaches the VRAMs directly — it goes through each 005885's bus
    interface (A/DBi/NXCS/NRD); the chip drives both BRAM ports (port A = CPU,
    port B = render scanner). See doc/k005885_port.md.

    GPL3 — see jtcores LICENSE.
    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
*/

module jtddribble_video(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               pxl2_cen,
    input               cpu_cen,

    // CPU bus (main MC6809E) — the chips decode their own register/VRAM windows
    input      [15:0]   main_A,
    input      [ 7:0]   main_dout,
    input               main_rnw,
    input               k5885_1_cs,        // chip 1 select (0x0000-0x07FF + 0x2000-0x3FFF)
    input               k5885_2_cs,        // chip 2 select (0x0800-0x0FFF + 0x6000-0x7FFF)
    output     [ 7:0]   k5885_1_dout,
    output     [ 7:0]   k5885_2_dout,

    // Graphics ROM bus to JTFRAME SDRAM (game.v maps R/RA1x to gfx{1,2}_addr)
    output     [15:0]   k5885_1_R,
    output              k5885_1_RA16,
    output              k5885_1_RA17,
    output              k5885_1_rom_cs,
    input      [15:0]   gfx1_data,
    input               gfx1_ok,
    output     [15:0]   k5885_2_R,
    output              k5885_2_RA16,
    output              k5885_2_RA17,
    output              k5885_2_rom_cs,
    input      [15:0]   gfx2_data,
    input               gfx2_ok,

    // Interrupts — chip 1 fans NFIR/NIRQ/NNMI to BOTH CPUs (game.v applies the
    // NFIR->IRQ / NIRQ->FIRQ swap).
    output              k5885_1_fir_n,
    output              k5885_1_irq_n,
    output              k5885_1_nmi_n,

    // Chip-owned video sync to the framework (chip 1 = master timing). Derived
    // from the same h_cnt/v_cnt that scans the tilemap, so the display window
    // and the rendered columns share one counter (no vtimer phase offset).
    output              LHBL,
    output              LVBL,
    output              HS,
    output              VS,

    // Palette BRAM read port (mem.yaml `pal` BRAM; CPU-write side is in game.v).
    output     [ 6:0]   pal_v_addr,
    input      [ 7:0]   pal_v_dout,

    // Chip VRAM (mem.yaml `vram1`/`vram2` dual-port BRAMs, D10/D11). Port A =
    // CPU-mediated, port B = render scan (read-only).
    output     [12:0]   vram1_cpu_addr,
    output     [ 7:0]   vram1_cpu_din,
    output              vram1_cpu_we,
    input      [ 7:0]   vram1_cpu_dout,
    output     [12:0]   vram1_scn_addr,
    input      [ 7:0]   vram1_scn_dout,
    output     [12:0]   vram2_cpu_addr,
    output     [ 7:0]   vram2_cpu_din,
    output              vram2_cpu_we,
    input      [ 7:0]   vram2_cpu_dout,
    output     [12:0]   vram2_scn_addr,
    input      [ 7:0]   vram2_scn_dout,

    // RGB to the JTFRAME framework — the colmix now lives in this module.
    output     [ 3:0]   red,
    output     [ 3:0]   green,
    output     [ 3:0]   blue,

    // Sprite-lookup PROM load (I15)
    input      [ 8:0]   prog_addr,
    input      [ 3:0]   prog_data,
    input               prom_we,

    // Debug
    input      [ 7:0]   debug_bus,
    input      [ 3:0]   gfx_en
);

// ---------------------------------------------------------------------------
// Chip 2 (H16) A11 mask — 007552 /G2AB11: chip 2 sees its registers at internal
// 0x0000-0x0007 even though the CPU addresses them at 0x0800-0x0807.
// ---------------------------------------------------------------------------
wire        k5885_2_in_regs   = (main_A[15:11] == 5'b00001);   // 0x0800-0x0FFF
wire        k5885_2_A11_masked= main_A[11] & ~k5885_2_in_regs;
wire [13:0] k5885_2_A         = { main_A[13:12], k5885_2_A11_masked, main_A[10:0] };

// Internal colour buses from the two 005885 chips → the colmix at the bottom of
// this module (these used to be outputs to game.v, where the colmix lived).
wire [ 6:0] k5885_1_pxl_out, k5885_2_pxl_out;

// ---------------------------------------------------------------------------
// 005885 chip 1 — FG layer (E16), gfx1
// ---------------------------------------------------------------------------
// Chip 1 sync (active-low Konami pins / active-high blanks) -> framework levels.
wire        k5885_1_HBLK, k5885_1_VBLK, k5885_1_NHSY, k5885_1_NYSY;
assign      LHBL = ~k5885_1_HBLK;
assign      LVBL = ~k5885_1_VBLK;
assign      HS   = ~k5885_1_NHSY;
assign      VS   = ~k5885_1_NYSY;

jtddribble_k005885 #(
    .LAYER_BG     ( 0          ),
    .OBJSTART     ( 18'h1_0000 ),
    .OBJMASK      ( 18'h0_FFFF )
) u_k5885_1 (
    .rst        ( rst            ),
    .clk        ( clk            ),
    .pxl_cen    ( pxl_cen        ),
    .cpu_cen    ( cpu_cen        ),
    // CPU bus (active-low Konami pins from active-high JTFRAME)
    .A          ( main_A[13:0]   ),
    .DBi        ( main_dout      ),
    .DBo        ( k5885_1_dout   ),
    .NXCS       ( ~k5885_1_cs    ),
    .NRD        ( ~main_rnw      ),
    .NEXR       ( 1'b1           ),
    .NIRQ       ( k5885_1_irq_n   ),
    .NNMI       ( k5885_1_nmi_n   ),
    .NFIR       ( k5885_1_fir_n   ),
    // gfx ROM
    .R          ( k5885_1_R      ),
    .RA16       ( k5885_1_RA16   ),
    .RA17       ( k5885_1_RA17   ),
    .RDU        ( gfx1_data[ 7:0]),
    .RDL        ( gfx1_data[15:8]),
    .rom_cs     ( k5885_1_rom_cs ),
    .rom_ok     ( gfx1_ok        ),
    // sync — chip 1 owns the framework's video timing
    .NHSY       ( k5885_1_NHSY   ),
    .NYSY       ( k5885_1_NYSY   ),
    .HBLK       ( k5885_1_HBLK   ),
    .VBLK       ( k5885_1_VBLK   ),
    // external 6264SL VRAM
    .vram_cpu_addr ( vram1_cpu_addr ),
    .vram_cpu_din  ( vram1_cpu_din  ),
    .vram_cpu_we   ( vram1_cpu_we   ),
    .vram_cpu_dout ( vram1_cpu_dout ),
    .vram_scn_addr ( vram1_scn_addr ),
    .vram_scn_dout ( vram1_scn_dout ),
    // PROM load
    .prog_addr  ( prog_addr      ),
    .prog_data  ( prog_data      ),
    .prom_we    ( prom_we        ),
    .pxl_out    ( k5885_1_pxl_out)
);

// ---------------------------------------------------------------------------
// 005885 chip 2 — BG layer (H16), gfx2
// ---------------------------------------------------------------------------
jtddribble_k005885 #(
    .LAYER_BG     ( 1          ),
    .BYPASS_OPROM ( 0          ),
    .OBJSTART     ( 18'h2_0000 ),
    .OBJMASK      ( 18'h1_FFFF )
) u_k5885_2 (
    .rst        ( rst            ),
    .clk        ( clk            ),
    .pxl_cen    ( pxl_cen        ),
    .cpu_cen    ( cpu_cen        ),
    .A          ( k5885_2_A      ),
    .DBi        ( main_dout      ),
    .DBo        ( k5885_2_dout   ),
    .NXCS       ( ~k5885_2_cs    ),
    .NRD        ( ~main_rnw      ),
    .NEXR       ( 1'b1           ),
    .NIRQ(), .NNMI(), .NFIR(),    // chip 2 interrupts unused (chip 1 drives both CPUs)
    .R          ( k5885_2_R      ),
    .RA16       ( k5885_2_RA16   ),
    .RA17       ( k5885_2_RA17   ),
    .RDU        ( gfx2_data[ 7:0]),
    .RDL        ( gfx2_data[15:8]),
    .rom_cs     ( k5885_2_rom_cs ),
    .rom_ok     ( gfx2_ok        ),
    .NHSY(), .NYSY(), .HBLK(), .VBLK(),   // chip 2 sync unused (chip 1 owns timing)
    .vram_cpu_addr ( vram2_cpu_addr ),
    .vram_cpu_din  ( vram2_cpu_din  ),
    .vram_cpu_we   ( vram2_cpu_we   ),
    .vram_cpu_dout ( vram2_cpu_dout ),
    .vram_scn_addr ( vram2_scn_addr ),
    .vram_scn_dout ( vram2_scn_dout ),
    .prog_addr  ( prog_addr      ),
    .prog_data  ( prog_data      ),
    .prom_we    ( prom_we        ),
    .pxl_out    ( k5885_2_pxl_out)
);

// ---------------------------------------------------------------------------
// Colour mixer — 007327 palette LUT / RGB DAC + LS157/LS32 priority network.
// Was started from jtcastle but then it diverged. in theory should be the same chip
// Fed by the two 005885 COL buses; reads the `pal` BRAM (CPU-write side in
// game.v); drives the framework RGB. (Was instantiated in game.v.)
// ---------------------------------------------------------------------------
jtddribble_colmix u_colmix(
    .rst        ( rst                  ),
    .clk        ( clk                  ),
    .pxl_cen    ( pxl_cen              ),
    .g1col      ( k5885_1_pxl_out[4:0] ),   // FG (chip 1)
    .g2col      ( k5885_2_pxl_out[4:0] ),   // BG (chip 2)
    .pal_addr   ( pal_v_addr           ),
    .pal_dout   ( pal_v_dout           ),
    .red        ( red                  ),
    .green      ( green                ),
    .blue       ( blue                 )
);

endmodule
