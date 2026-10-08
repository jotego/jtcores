/*  jtddrbl_video.v — Video pipeline for Double Dribble (Konami GX690)

    Per jtcores convention this "_video" module is the video PIPELINE: it holds
    the two Konami 005885 graphics generators (E16 = FG, H16 = BG). Their 8 KB
    6264SL VRAMs are mem.yaml dual-port BRAMs (vram1/vram2); this module exposes
    each chip's VRAM ports up to game.v, which wires them to those BRAMs. The
    colour side (007327 palette + LS157 priority mux + sync) is jtddrbl_colmix.v.
    jtddrbl_game.v instantiates this module and the colmix module.

    The CPU never reaches the VRAMs directly — it goes through each 005885's bus
    interface (A/din/NXCS/NRD); the chip drives both BRAM ports (port A = CPU,
    port B = render scanner). See doc/k005885_port.md.

    GPL3 — see jtcores LICENSE.
    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
*/

module jtddrbl_video(
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
    output     [17:2]   gfx1_addr,
    output              gfx1_cs,
    input      [31:0]   gfx1_data,
    input               gfx1_ok,
    output     [18:2]   gfx2_addr,
    output              gfx2_cs,
    input      [31:0]   gfx2_data,
    input               gfx2_ok,
    // sprite gfx slots (own SDRAM bus per chip)
    output     [17:2]   gfx1obj_addr,
    output              gfx1obj_cs,
    input      [31:0]   gfx1obj_data,
    input               gfx1obj_ok,
    output     [18:2]   gfx2obj_addr,
    output              gfx2obj_cs,
    input      [31:0]   gfx2obj_data,
    input               gfx2obj_ok,

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

    output     [ 4:0]   red,
    output     [ 4:0]   green,
    output     [ 4:0]   blue,

    // Sprite-lookup PROM load (I15)
    input      [ 7:0]   prog_addr,
    input      [ 3:0]   prog_data,
    input               prom_we,

    // Debug
    input      [ 7:0]   debug_bus,
    input      [ 3:0]   gfx_en
);

wire [ 6:0] k5885_1_pxl, k5885_2_pxl;
wire        prom_1_we, prom_2_we;

wire        k5885_2_in_regs   = (main_A[15:11] == 5'b00001);   // 0x0800-0x0FFF
wire        k5885_2_A11_masked= main_A[11] & ~k5885_2_in_regs;
wire [13:0] k5885_2_A         = { main_A[13:12], k5885_2_A11_masked, main_A[10:0] };

wire        k5885_1_HBLK, k5885_1_VBLK, k5885_1_NHSY, k5885_1_NYSY;
wire [ 3:0] gfx2_ocf, gfx2_ocb, gfx2_ocd;
wire [ 3:0] gfx1_ocb;

// gfx-slot address adapters: chip1's obj_addr top bit is always 0 (fits gfx1's
// 16-bit slot); chip2's tile addr is the low half (RA16=0) of its 17-bit slot.
wire [16:0] k1_obj_addr;
wire [15:0] k2_scr_addr;
assign gfx1obj_addr = k1_obj_addr[15:0];
assign gfx2_addr    = { 1'b0, k2_scr_addr };

assign LHBL = ~k5885_1_HBLK;
assign LVBL = ~k5885_1_VBLK;
assign HS   = ~k5885_1_NHSY;
assign VS   = ~k5885_1_NYSY;

jtddrbl_k005885 #(
    .LAYER_BG     ( 0          ),
    .OBJSTART     ( 18'h1_0000 ),
    .OBJMASK      ( 18'h0_FFFF )
) u_k5885_1 (
    .rst        ( rst            ),
    .clk        ( clk            ),
    .pxl_cen    ( pxl_cen        ),
    .cpu_cen    ( cpu_cen        ),

    .A          ( main_A[13:0]   ),
    .din        ( main_dout      ),
    .dout       ( k5885_1_dout   ),
    .NXCS       ( ~k5885_1_cs    ),
    .NRD        ( ~main_rnw      ),
    .NEXR       ( 1'b1           ),
    .NIRQ       ( k5885_1_irq_n   ),
    .NNMI       ( k5885_1_nmi_n   ),
    .NFIR       ( k5885_1_fir_n   ),
    // gfx ROM — tile slot (gfx1) + sprite slot (gfx1obj)
    .scr_addr   ( gfx1_addr[17:2]),
    .scr_cs     ( gfx1_cs        ),
    .scr_data   ( gfx1_data      ),
    .scr_ok     ( gfx1_ok        ),
    .obj_addr   ( k1_obj_addr    ),
    .obj_cs     ( gfx1obj_cs     ),
    .obj_data   ( gfx1obj_data   ),
    .obj_ok     ( gfx1obj_ok     ),
    .OCF        (                ),
    .OCB        ( gfx1_ocb       ),
    .OCD        ( gfx1_ocb       ),
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

    .pxl_out       ( k5885_1_pxl    )
);

jtddrbl_k005885 #(
    .LAYER_BG     ( 1          ),
    .OBJSTART     ( 18'h2_0000 ),
    .OBJMASK      ( 18'h1_FFFF )
) u_k5885_2 (
    .rst        ( rst            ),
    .clk        ( clk            ),
    .pxl_cen    ( pxl_cen        ),
    .cpu_cen    ( cpu_cen        ),
    .A          ( k5885_2_A      ),
    .din        ( main_dout      ),
    .dout       ( k5885_2_dout   ),
    .NXCS       ( ~k5885_2_cs    ),
    .NRD        ( ~main_rnw      ),
    .NEXR       ( 1'b1           ),
    .NIRQ(), .NNMI(), .NFIR(),    // chip 2 interrupts unused (chip 1 drives both CPUs)
    // gfx ROM — tile slot (gfx2) + sprite slot (gfx2obj)
    .scr_addr   ( k2_scr_addr    ),
    .scr_cs     ( gfx2_cs        ),
    .scr_data   ( gfx2_data      ),
    .scr_ok     ( gfx2_ok        ),
    .obj_addr   ( gfx2obj_addr   ),
    .obj_cs     ( gfx2obj_cs     ),
    .obj_data   ( gfx2obj_data   ),
    .obj_ok     ( gfx2obj_ok     ),
    .OCF        ( gfx2_ocf       ),
    .OCB        ( gfx2_ocb       ),
    .OCD        ( gfx2_ocd       ),
    .vram_cpu_addr ( vram2_cpu_addr ),
    .vram_cpu_din  ( vram2_cpu_din  ),
    .vram_cpu_we   ( vram2_cpu_we   ),
    .vram_cpu_dout ( vram2_cpu_dout ),
    .vram_scn_addr ( vram2_scn_addr ),
    .vram_scn_dout ( vram2_scn_dout ),

    .pxl_out       ( k5885_2_pxl    ),
    // chip 2 sync unused (chip 1 owns timing)
    .NHSY(), .NYSY(), .HBLK(), .VBLK()
);

jtframe_prom #(.AW(8),.DW(4),.ASYNC(1)) u_prom(
    .clk    ( clk                ),
    .cen    ( 1'b1               ),
    .we     ( prom_we            ),
    .data   ( prog_data          ),
    .wr_addr( prog_addr          ),
    .rd_addr({gfx2_ocf, gfx2_ocb}),
    .q      ( gfx2_ocd           )
);


// ---------------------------------------------------------------------------
// Colour mixer — 007327 palette LUT / RGB DAC + LS157/LS32 priority network.
// Fed by the two 005885 COL buses; reads the `pal` BRAM (CPU-write side in
// game.v); drives the framework RGB.
// ---------------------------------------------------------------------------
jtddrbl_colmix u_colmix(
    .rst        ( rst              ),
    .clk        ( clk              ),
    .pxl_cen    ( pxl_cen          ),
    .lhbl       ( LHBL             ),
    .lvbl       ( LVBL             ),
    .g1col      ( k5885_1_pxl[4:0] ),   // FG (chip 1)
    .g2col      ( k5885_2_pxl[4:0] ),   // BG (chip 2)
    .pal_addr   ( pal_v_addr       ),
    .pal_dout   ( pal_v_dout       ),
    .red        ( red              ),
    .green      ( green            ),
    .blue       ( blue             ),
    .debug_bus  ( debug_bus        )
);

endmodule
