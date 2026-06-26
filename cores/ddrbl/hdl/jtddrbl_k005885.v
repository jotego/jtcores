//============================================================================
//  jtddrbl_k005885.v — Konami 005885 for Double Dribble (GX690).
//  Hosted in JTFRAME (framework clk + clock-enables, SDRAM gfx on one
//  time-shared ROM bus). Instantiated twice: E16=FG/gfx1, H16=BG/gfx2; each
//  emits COL[4:0] into jtddrbl_colmix.
//----------------------------------------------------------------------------
//  Portions derived from the MIT-licensed k005885.sv by Ace. MIT notice:
//    Permission is hereby granted, free of charge, to any person obtaining a
//    copy of this software and associated documentation files (the
//    "Software"), to deal in the Software without restriction... The above
//    copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software. THE SOFTWARE IS
//    PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
//  JTCORES integration is GPL-3 (see jtcores LICENSE).
//
//  Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
//============================================================================

module jtddrbl_k005885 #(
    // 0 = FG (chip 1, gfx1, 12-bit code), 1 = BG (chip 2, gfx2, 13-bit code)
    parameter        LAYER_BG = 0,
    // Sprite-ROM region (sprite patterns live in the upper half of each gfx region)
    parameter [17:0] OBJSTART = 18'h0_0000,
    parameter [17:0] OBJMASK  = 18'h3_FFFF,
    // Screen-centering (model convenience, tunable per instance)
    parameter [3:0]  HCTR = 4'd0,
    parameter [3:0]  VCTR = 4'd0,
    // Scene-replay SIMFILE names (per chip)
    parameter SIMATTR = "gfx_attr.bin",
    parameter SIMCODE = "gfx_code.bin",
    parameter SIMOBJ  = "gfx_obj.bin"
) (
    // CPU bus
    input      [13:0]  A,
    input      [ 7:0]  din,
    output     [ 7:0]  dout,
    input              NXCS,         // chip select
    input              NRD,          // read enable; =1 means write
    input              NEXR,         // external reset

    // CPU interrupt outputs (game.v applies the NFIR/NIRQ swap)
    output             NIRQ,
    output             NNMI,
    output             NFIR,

    // Graphics-ROM bus. The chip emits R[15:0]; RA16/RA17 (made off-chip by the
    // LS74 chain on the PCB) are exposed so game.v drives the gfx-region MSBs.
    output             RA17,
    output             RA16,
    output     [15:0]  R,
    input      [31:0]  RD,           // 32-bit packed gfx row (jtframe_scroll path)

    output     [ 3:0]  OCF,OCB,
    input      [ 3:0]  OCD,
    // Vertical sync (active low). Final COL[4:0] is exposed via pxl_out below.
    output             NYSY,

    // JTFRAME framework I/O (not on the real chip): fast clk + clock-enables,
    // SDRAM ready handshake, PROM-load path. Wired in game.v.
    input              rst,
    input              clk,
    input              pxl_cen,             // pixel-rate clock-enable (clk/8)
    input              cpu_cen,             // CPU-rate clock-enable

    // SDRAM ready-handshake (graphics ROM fetch)
    input              rom_ok,
    output             rom_cs,

    // Video blanking (active high) + hsync (active low)
    output             HBLK,
    output             VBLK,
    output             NHSY,

    // External 8 KB 6264SL VRAM (tile attr/code + sprite list), modeled as a
    // mem.yaml dual-port BRAM in jtddrbl_video.v. Port A = CPU-mediated
    // (tile A[12]=0, sprite A[12]=1), port B = render scanner.
    output     [12:0]  vram_cpu_addr,
    output     [ 7:0]  vram_cpu_din,
    output             vram_cpu_we,
    input      [ 7:0]  vram_cpu_dout,
    output     [12:0]  vram_scn_addr,
    input      [ 7:0]  vram_scn_dout,

    // Colour output to colmix: pxl_out[4:0] = COL.
    output     [ 6:0]  pxl_out
);

// Effective reset: framework rst (active high) OR external NEXR (active low).
wire chip_rst = rst | ~NEXR;

wire cen_6m = pxl_cen;     // chip pixel clock

//------------------------------------------------------------------------
//  Video timing — jtframe_vtimer (E1).  Drives h_cnt/v_cnt for the render
//  FSM; chip-owned sync (HBLK/VBLK/NHSY/NYSY) derived from the vtimer.
//  384x262 total, visible 256x224 (H 14..269, V 16..239), VS 256..258, HS 303..334.
//------------------------------------------------------------------------
wire [8:0] vt_H, vt_vdump;
wire       vt_lhbl, vt_lvbl, vt_hs, vt_vs;
jtframe_vtimer #(
    .HCNT_END ( 9'd383 ),
    .HB_START ( 9'd269 ),   // LHBL=0 at 269 -> visible 14..269 (256 px)
    .HB_END   ( 9'd13  ),   // LHBL=1 at 13  -> visible opens at 14
    .HS_START ( 9'd302 ),   // HS high 303..334 (matches _old HSYNC 303..335 window)
    .HS_END   ( 9'd334 ),
    .VCNT_END ( 9'd261 ),
    .VB_START ( 9'd239 ),   // visible 16..239 (224 lines)
    .VB_END   ( 9'd15  ),
    .VS_START ( 9'd256 ),   // VS high 256..258 (3 lines, satisfies >=3 assert)
    .VS_END   ( 9'd259 )
) u_vtimer(
    .clk     ( clk      ),
    .pxl_cen ( pxl_cen  ),
    .vdump   ( vt_vdump ),
    .vrender (          ),
    .vrender1(          ),
    .H       ( vt_H     ),
    .Hinit   (          ),
    .Vinit   (          ),
    .LHBL    ( vt_lhbl  ),
    .LVBL    ( vt_lvbl  ),
    .HS      ( vt_hs    ),
    .VS      ( vt_vs    )
);
wire [8:0] h_cnt  = vt_H;
wire [8:0] v_cnt  = vt_vdump;
wire       vblank = ~vt_lvbl;
assign HBLK = ~vt_lhbl;
assign VBLK = ~vt_lvbl;
assign NHSY = ~vt_hs;
assign NYSY = ~vt_vs;

wire hblank = ~vt_lhbl;   // feeds the sprite engine's display-read gate

// Edge-detect for the interrupt logic (IRQ/NMI/FIRQ).
reg old_vcnt4, old_vcnt5, old_vblank;
always @(posedge clk) begin
    old_vcnt4  <= v_cnt[4];
    old_vcnt5  <= v_cnt[5];
    old_vblank <= vblank;
end

//------------------------------------------------------------------------
//  Control registers (5)
//------------------------------------------------------------------------
//  000: scroll y      001: scroll x low 8     002: bit0 scroll x hi; b3:1 row/col ctrl
//  003: b1:0 hi tile code; b3 sprite-buf sel  004: b0 nmi en, b1 irq en, b2 firq en, b3 flip
wire regs_cs = ~NXCS & (A[13:11] == 3'b000) & (A[6:3] == 4'd0);

reg [7:0] scroll_y   = 8'd0;
reg [7:0] scroll_x   = 8'd0;
reg [7:0] scroll_ctrl= 8'd0;
reg [7:0] tile_ctrl  = 8'd0;
reg nmi_mask = 0, irq_mask = 0, firq_mask = 0, flipscreen = 0;

always @(posedge clk) if(cpu_cen) begin
    if(regs_cs && NRD)              // NRD=1 => write cycle (registers clocked on cpu_cen)
        case(A[2:0])
            3'b000: scroll_y    <= din;
            3'b001: scroll_x    <= din;
            3'b010: scroll_ctrl <= din;
            3'b011: tile_ctrl   <= din;
            3'b100: begin
                nmi_mask   <= din[0];
                irq_mask   <= din[1];
                firq_mask  <= din[2];
                flipscreen <= din[3];
            end
            default:;
        endcase
end

//------------------------------------------------------------------------
//  Interrupts
//------------------------------------------------------------------------
reg vblank_irq = 1;
always @(posedge clk) begin
    if(chip_rst || !irq_mask)        vblank_irq <= 1;
    else if(!old_vblank && vblank)   vblank_irq <= 0;
end
assign NIRQ = vblank_irq;

reg nmi = 1;
always @(posedge clk) begin
    if(chip_rst || !nmi_mask) nmi <= 1;
    else if(tile_ctrl[2]) begin if(old_vcnt4 && !v_cnt[4]) nmi <= 0; end
    else                  begin if(old_vcnt5 && !v_cnt[5]) nmi <= 0; end
end
assign NNMI = nmi;

reg firq = 1;
always @(posedge clk) begin
    if(chip_rst || !firq_mask)       firq <= 1;
    else if(!old_vblank && vblank)   firq <= 0;   // every vblank (E2: no frame ÷2)
end
assign NFIR = firq;

//------------------------------------------------------------------------
//  Internal RAM (ZRAM + scratch; 8 KB tile/sprite VRAM is external)
//------------------------------------------------------------------------
// scratch 0x05-0x1F, ZRAM0 0x20-0x3F, ZRAM1 0x40-0x5F, ZRAM2 0x60-0xDF,
// tile VRAM (A[13:12]=10), sprite VRAM (A[13:12]=11).
wire ram_cs      = ~NXCS & (A >= 14'h0005 && A <= 14'h001F);
wire zram0_cs    = ~NXCS & (A >= 14'h0020 && A <= 14'h003F);
wire zram1_cs    = ~NXCS & (A >= 14'h0040 && A <= 14'h005F);
wire zram2_cs    = ~NXCS & (A >= 14'h0060 && A <= 14'h00DF);
wire tile_cs     = ~NXCS & (A[13:12] == 2'b10);
wire spriteram_cs= ~NXCS & (A[13:12] == 2'b11);

wire [7:0] ram_Dout, zram0_Dout, zram1_Dout, zram2_Dout;

// External 6264SL VRAM, port A (CPU-mediated). Write captured once per cpu_cen
// (NRD=1 => write); port B (render scanner) is driven by the FSM below.
assign vram_cpu_addr = A[12:0];
assign vram_cpu_din  = din;
assign vram_cpu_we   = (tile_cs | spriteram_cs) & NRD & cpu_cen;

// ---- Internal scratch / ZRAM (NOT external on the schematic) ---------
jtframe_dual_ram #(.DW(8),.AW(5)) u_ram(
    .clk0(clk), .data0(din), .addr0(A[4:0]), .we0(ram_cs & NRD), .q0(ram_Dout),
    .clk1(clk), .data1(8'd0),.addr1(5'd0),   .we1(1'b0),         .q1()
);
jtframe_dual_ram #(.DW(8),.AW(5)) u_zram0(
    .clk0(clk), .data0(din), .addr0(A[4:0]), .we0(zram0_cs & NRD), .q0(zram0_Dout),
    .clk1(clk), .data1(8'd0),.addr1(5'd0),   .we1(1'b0),          .q1()
);
jtframe_dual_ram #(.DW(8),.AW(5)) u_zram1(
    .clk0(clk), .data0(din), .addr0(A[4:0]), .we0(zram1_cs & NRD), .q0(zram1_Dout),
    .clk1(clk), .data1(8'd0),.addr1(5'd0),   .we1(1'b0),          .q1()
);
jtframe_dual_ram #(.DW(8),.AW(7)) u_zram2(
    .clk0(clk), .data0(din), .addr0(A[6:0]), .we0(zram2_cs & NRD), .q0(zram2_Dout),
    .clk1(clk), .data1(8'd0),.addr1(7'd0),   .we1(1'b0),          .q1()
);

// CPU read mux (NRD=0 => read)
assign dout = (ram_cs       & ~NRD) ? ram_Dout      :
             (zram0_cs     & ~NRD) ? zram0_Dout    :
             (zram1_cs     & ~NRD) ? zram1_Dout    :
             (zram2_cs     & ~NRD) ? zram2_Dout    :
             ((tile_cs|spriteram_cs) & ~NRD) ? vram_cpu_dout :
             8'hFF;


//------------------------------------------------------------------------
//  Tilemap renderer — jtframe_scroll + jtframe_8x8x4_packed_msb (E3/A3).
//------------------------------------------------------------------------
wire [15:0] scroll_rom_addr;
wire        scroll_rom_cs;
wire [12:0] scroll_vram_addr;
wire [ 4:0] sc_pxl;

jtddrbl_scroll #( .LAYER_BG(LAYER_BG) ) u_scroll(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .pxl_cen  ( pxl_cen     ),
    .hs       ( vt_hs       ),
    .blankn   ( vt_lvbl & (h_cnt < 9'd272) ),  // tiles fetch h_cnt 0..271; obj_win (272+) is the sprites'
    .flip     ( flipscreen  ),
    .vdump    ( v_cnt       ),
    .hdump    ( h_cnt       ),
    .scrx     ( {scroll_ctrl[0], scroll_x} ),
    .scry     ( scroll_y    ),
    .tile_hi  ( LAYER_BG ? tile_ctrl[1:0] : {1'b0, tile_ctrl[1]} ),
    .vram_addr( scroll_vram_addr ),
    .vram_dout( vram_scn_dout    ),
    .rom_cs   ( scroll_rom_cs    ),
    .rom_addr ( scroll_rom_addr  ),
    .rom_data ( RD               ),                 // 32-bit packed gfx
    .rom_ok   ( rom_ok           ),
    .pxl      ( sc_pxl           )
);

//------------------------------------------------------------------------
//  Sprite engine — jtddrbl_obj on the 32-bit gfx bus. Time-shares the gfx
//  ROM with the tilemap (sprites in obj_win h_cnt>=272, tiles otherwise). OBJ
//  list = vblank snapshot (sprite frame-buffer 1-frame delay).
//------------------------------------------------------------------------
wire obj_win = h_cnt >= 9'd272;

localparam OBJ_AW = 9;                  // OBJ list <=320 B -> 512-entry shadow
wire [OBJ_AW-1:0] dma_addr;
wire              dma_we;
wire [7:0]        obj_list_dout;
wire [11:0]       obj_rd_addr;
jtframe_bram_dma #(.AW(OBJ_AW)) u_objdma(
    .rst(rst), .clk(clk), .cen(pxl_cen),    // cen must NOT be 1'b1
    .addr(dma_addr), .start(vblank), .we(dma_we)
);
jtframe_dual_ram #(.DW(8),.AW(OBJ_AW)) u_objshadow(
    .clk0(clk), .data0(vram_scn_dout), .addr0(dma_addr), .we0(dma_we & pxl_cen), .q0(),
    .clk1(clk), .data1(8'd0), .addr1(obj_rd_addr[OBJ_AW-1:0]), .we1(1'b0), .q1(obj_list_dout)
);

// VRAM scan port: tilemap owns it; the snapshot DMA borrows it during vblank.
assign vram_scn_addr = dma_we ? { 1'b1, 3'd0, dma_addr } : scroll_vram_addr;

// sprite gfx: the engine reads 16-bit; pick the right half of the 32-bit word.
// Low half (RD[15:0]) = first 4px, same packing as the tilemap.
wire [17:0] spr_rom_addr;
wire        spr_rom_cs;
wire        spr_half = spr_rom_addr[0];
wire [15:0] spr_gfx16 = spr_half ? RD[31:16] : RD[15:0];
wire [3:0]  obj_pxl;
jtddrbl_obj #(
    .LAYER_BG     ( LAYER_BG     ),
    .OBJSTART     ( OBJSTART     ),
    .OBJMASK      ( OBJMASK      )
) u_obj(
    .clk          ( clk            ),
    .rst          ( rst            ),
    .pxl_cen      ( pxl_cen        ),
    .h_cnt        ( h_cnt          ),
    .v_cnt        ( v_cnt          ),
    .obj_win      ( obj_win        ),
    .hblank       ( hblank         ),
    .obj_rd_addr  ( obj_rd_addr    ),
    .vram_scn_dout( obj_list_dout  ),   // snapshot shadow, not the live VRAM
    .rom_addr     ( spr_rom_addr   ),
    .rom_cs       ( spr_rom_cs     ),
    .RDU          ( spr_gfx16[ 7:0]),
    .RDL          ( spr_gfx16[15:8]),
    .OCF          ( OCF            ),
    .OCB          ( OCB            ),
    .OCD          ( OCD            ),
    .rom_ok       ( rom_ok         ),
    .obj_pxl      ( obj_pxl        )
);

//  gfx ROM bus: sprites during obj_win, tilemap otherwise. RD is 32-bit; the
//  sprite addresses 32-bit words via spr_rom_addr[16:1] (bit[0] = the half).
assign R      = obj_win ? spr_rom_addr[16:1] : scroll_rom_addr;
assign RA16   = obj_win ? spr_rom_addr[17]   : 1'b0;
assign RA17   = 1'b0;
assign rom_cs = obj_win ? spr_rom_cs : scroll_rom_cs;

// COL out: opaque sprite over tile.
assign pxl_out = { 2'b00, (obj_pxl != 4'h0) ? { 1'b0, obj_pxl } : { 1'b1, sc_pxl[3:0] } };

endmodule
