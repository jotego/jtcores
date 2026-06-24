//============================================================================
//  jtddribble_k005885.v — Konami 005885 for Double Dribble (GX690).
//  Hosted in JTFRAME (framework clk + clock-enables, SDRAM gfx on one
//  time-shared ROM bus). Instantiated twice: E16=FG/gfx1, H16=BG/gfx2; each
//  emits COL[4:0] into jtddribble_colmix.
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

module jtddribble_k005885 #(
    // Sprite colour: 0 = use the 256-byte I15 LUT PROM (chip 2), 1 = pens 1:1 (chip 1)
    parameter BYPASS_OPROM = 1,
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
    input      [ 7:0]  DBi,          // data in
    output     [ 7:0]  DBo,          // data out
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
    input      [ 7:0]  RDU,          // upper byte
    input      [ 7:0]  RDL,          // lower byte

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

    // PROM-loading interface (sprite-colour LUT)
    input      [ 8:0]  prog_addr,           // [8] gates the low 256 entries
    input      [ 3:0]  prog_data,
    input              prom_we,

    // Video blanking (active high) + hsync (active low)
    output             HBLK,
    output             VBLK,
    output             NHSY,

    // External 8 KB 6264SL VRAM (tile attr/code + sprite list), modeled as a
    // mem.yaml dual-port BRAM in jtddribble_video.v. Port A = CPU-mediated
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
            3'b000: scroll_y    <= DBi;
            3'b001: scroll_x    <= DBi;
            3'b010: scroll_ctrl <= DBi;
            3'b011: tile_ctrl   <= DBi;
            3'b100: begin
                nmi_mask   <= DBi[0];
                irq_mask   <= DBi[1];
                firq_mask  <= DBi[2];
                flipscreen <= DBi[3];
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
assign vram_cpu_din  = DBi;
assign vram_cpu_we   = (tile_cs | spriteram_cs) & NRD & cpu_cen;

// ---- Internal scratch / ZRAM (NOT external on the schematic) ---------
jtframe_dual_ram #(.DW(8),.AW(5)) u_ram(
    .clk0(clk), .data0(DBi), .addr0(A[4:0]), .we0(ram_cs & NRD), .q0(ram_Dout),
    .clk1(clk), .data1(8'd0),.addr1(5'd0),   .we1(1'b0),         .q1()
);
jtframe_dual_ram #(.DW(8),.AW(5)) u_zram0(
    .clk0(clk), .data0(DBi), .addr0(A[4:0]), .we0(zram0_cs & NRD), .q0(zram0_Dout),
    .clk1(clk), .data1(8'd0),.addr1(5'd0),   .we1(1'b0),          .q1()
);
jtframe_dual_ram #(.DW(8),.AW(5)) u_zram1(
    .clk0(clk), .data0(DBi), .addr0(A[4:0]), .we0(zram1_cs & NRD), .q0(zram1_Dout),
    .clk1(clk), .data1(8'd0),.addr1(5'd0),   .we1(1'b0),          .q1()
);
jtframe_dual_ram #(.DW(8),.AW(7)) u_zram2(
    .clk0(clk), .data0(DBi), .addr0(A[6:0]), .we0(zram2_cs & NRD), .q0(zram2_Dout),
    .clk1(clk), .data1(8'd0),.addr1(7'd0),   .we1(1'b0),          .q1()
);

// CPU read mux (NRD=0 => read)
assign DBo = (ram_cs       & ~NRD) ? ram_Dout      :
             (zram0_cs     & ~NRD) ? zram0_Dout    :
             (zram1_cs     & ~NRD) ? zram1_Dout    :
             (zram2_cs     & ~NRD) ? zram2_Dout    :
             ((tile_cs|spriteram_cs) & ~NRD) ? vram_cpu_dout :
             8'hFF;

//------------------------------------------------------------------------
//  Tilemap line-buffer renderer (007121 mechanism)
//------------------------------------------------------------------------
// The scanline is rendered into a double-buffered line buffer at the fine-scroll
// column tm_hrender, read back at the screen column. The render FSM time-shares
// the VRAM + gfx ROM ports with the sprite engine (tilemap when h_cnt<272,
// sprites in obj_win). Render leads display by one line; the buffer's 1-line
// read latency cancels it.
reg  [3:0]  tm_st;
reg  [1:0]  tm_wait;
reg         tm_run, tm_sel, tm_line, old_tm_obj;
reg  [8:0]  tm_hn;          // scan h = {scroll_ctrl[0],scroll_x}, +4 per gfx half
reg  [8:0]  tm_hrender;     // line-buffer write column (fine offset applied)
reg  [5:0]  tm_col;         // tiles rendered this line
reg  [1:0]  tm_bank;
reg  [7:0]  tm_index;
reg         tm_hflip, tm_vflip, tm_a5;
reg  [15:0] tm_word;
reg  [1:0]  tm_dn;
reg         tm_we;
reg  [8:0]  tm_waddr;
reg  [3:0]  tm_wdata;

wire [11:0] obj_rd_addr;
wire        obj_win  = h_cnt >= 9'd272;
wire [8:0]  tm_vpos  = ((v_cnt + 9'd1) ^ {9{flipscreen}}) + {1'd0, scroll_y};
// SIM-only fine-scroll test hook (-d SIM_SCROLLX=N); scroll_x is otherwise 0
// because the scene-sim CPU is stubbed.
`ifdef SIM_SCROLLX
wire [7:0]  r_scroll_x = `SIM_SCROLLX;
`else
wire [7:0]  r_scroll_x = scroll_x;
`endif
// VRAM scan port: render FSM owns it in the non-obj window, sprite scan in obj_win
assign vram_scn_addr = obj_win ? { 1'b1, obj_rd_addr }
                               : { 1'b0, tm_hn[8], ~tm_sel, tm_vpos[7:3], tm_hn[7:3] };

// Tile gfx address for the current 4px half (tm_hn[2] selects the half)
wire [12:0] tm_code = { LAYER_BG ? tile_ctrl[1:0] : { 1'b0, tile_ctrl[1] },
                        tm_a5, tm_bank, tm_index };
wire [16:0] tm_rom_addr = { tm_code, tm_vpos[2:0] ^ {3{tm_vflip}}, tm_hn[2] ^ tm_hflip };
wire        tm_rom_cs   = tm_run && (tm_st==4'd2 || tm_st==4'd3);
wire [3:0]  tm_pixel    = tm_hflip ? tm_word[3:0] : tm_word[15:12];

// gfx ROM port — TIME-SHARED tilemap render (non-obj) / sprite (obj_win)
wire [17:0] spr_rom_addr;
wire        spr_rom_cs;
wire [17:0] rom_addr = obj_win ? spr_rom_addr : { 1'b0, tm_rom_addr };
assign R      = rom_addr[15:0];
assign RA16   = rom_addr[16];
assign RA17   = rom_addr[17];
assign rom_cs = obj_win ? spr_rom_cs : tm_rom_cs;

// Render FSM: per tile read ATTR then CODE, fetch the two 4px gfx halves, dump
// each into the line buffer at tm_hrender. Fine scroll = scroll_x[1:0] offset.
always @(posedge clk) begin
    old_tm_obj <= obj_win;
    tm_we      <= 1'b0;
    if (rst) begin
        tm_run<=0; tm_st<=0; tm_line<=0; tm_sel<=1; tm_wait<=0;
        tm_hn<=0; tm_hrender<=0; tm_col<=0;
    end else if (old_tm_obj && !obj_win) begin   // line start (obj_win falling)
        tm_run    <= 1'b1;
        tm_st     <= 4'd0;
        tm_sel    <= 1'b1;                         // attr byte first
        tm_wait   <= 2'd0;
        tm_col    <= 6'd0;
        tm_hn     <= { scroll_ctrl[0], r_scroll_x };
        tm_hrender<= TM_HSTART - { 7'd0, r_scroll_x[1:0] };
        tm_line   <= ~tm_line;                     // swap double buffer
    end else if (obj_win) begin
        tm_run    <= 1'b0;
    end else if (tm_run) case (tm_st)
        4'd0: if (tm_wait!=2'd2) tm_wait<=tm_wait+2'd1;   // read ATTR (tm_sel=1)
              else begin tm_wait<=2'd0;
                  tm_bank <= vram_scn_dout[7:6];
                  tm_hflip<= vram_scn_dout[4];
                  tm_vflip<= vram_scn_dout[5];
                  tm_a5   <= vram_scn_dout[5];
                  tm_sel  <= 1'b0; tm_st<=4'd1; end
        4'd1: if (tm_wait!=2'd2) tm_wait<=tm_wait+2'd1;   // read CODE (tm_sel=1)
              else begin tm_wait<=2'd0; tm_index<=vram_scn_dout; tm_st<=4'd2; end
        4'd2: tm_st<=4'd3;                                // issue gfx fetch
        4'd3: if (rom_ok) begin tm_word<={RDU,RDL}; tm_dn<=2'd0; tm_st<=4'd4; end
        4'd4: begin                                       // dump 4 px into the buffer
                  tm_we     <= 1'b1;
                  tm_waddr  <= tm_hrender;
                  tm_wdata  <= tm_pixel;
                  tm_hrender <= tm_hrender + 9'd1;
                  tm_word   <= tm_hflip ? {4'd0, tm_word[15:4]} : {tm_word[11:0], 4'd0};
                  tm_dn     <= tm_dn + 2'd1;
                  if (tm_dn==2'd3) begin
                      tm_hn <= tm_hn + 9'd4;
                      if (!tm_hn[2]) tm_st <= 4'd2;        // half0 done -> half1 (same tile)
                      else begin                          // half1 done -> next tile
                          tm_sel <= 1'b1; tm_st <= 4'd0;
                          tm_col <= tm_col + 6'd1;
                          if (tm_col >= 6'd33) tm_run <= 1'b0;
                      end
                  end
              end
        default: tm_run<=1'b0;
    endcase
end

// Tilemap line buffer (double-buffered): render writes bank tm_line, display
// reads bank ~tm_line. Read column derived straight from h_cnt to avoid a
// pre-display wrap. 9-bit column so the 34-tile render never wraps onto visible.
localparam [8:0] TM_HSTART = 9'd6;      // render/display column offset
wire [8:0] tm_rdcol = h_cnt - TM_HSTART;
wire [3:0] tm_buf_px;
jtframe_dual_ram #(.DW(4), .AW(10)) u_tm_line(
    .clk0 ( clk ), .clk1 ( clk ),
    .data0( tm_wdata ), .addr0( { tm_line,  tm_waddr } ), .we0( tm_we ), .q0(),
    .data1( 4'd0 ),     .addr1( { ~tm_line, tm_rdcol } ), .we1( 1'b0 ), .q1( tm_buf_px )
);
reg [3:0] tilemap_px;
always @(posedge clk) if(cen_6m) tilemap_px <= tm_buf_px;

//------------------------------------------------------------------------
//  Sprite engine (005885 OBJ) — own module (D9). Time-shares the VRAM-scan
//  and gfx-ROM ports with the tilemap above (muxed by obj_win); the parent
//  drives the shared buses from obj_rd_addr / spr_rom_addr.
//------------------------------------------------------------------------
wire [3:0] obj_pxl;     // looked-up sprite colour (OCD); 0 = transparent
jtddribble_obj #(
    .BYPASS_OPROM ( BYPASS_OPROM ),
    .LAYER_BG     ( LAYER_BG     ),
    .OBJSTART     ( OBJSTART     ),
    .OBJMASK      ( OBJMASK      )
) u_obj (
    .clk          ( clk           ),
    .rst          ( rst           ),
    .pxl_cen      ( pxl_cen       ),
    .h_cnt        ( h_cnt         ),
    .v_cnt        ( v_cnt         ),
    .obj_win      ( obj_win       ),
    .hblank       ( hblank        ),
    .obj_rd_addr  ( obj_rd_addr   ),
    .vram_scn_dout( vram_scn_dout ),
    .spr_rom_addr ( spr_rom_addr  ),
    .spr_rom_cs   ( spr_rom_cs    ),
    .RDU          ( RDU           ),
    .RDL          ( RDL           ),
    .rom_ok       ( rom_ok        ),
    .prog_addr    ( prog_addr     ),
    .prog_data    ( prog_data     ),
    .prom_we      ( prom_we       ),
    .obj_pxl      ( obj_pxl       )
);

//------------------------------------------------------------------------
//  Colour out — sprite over tilemap into COL[4:0]
//------------------------------------------------------------------------
// Opaque sprite -> COL[4]=0, tile -> COL[4]=1 (COL[4] picks the palette half).
wire [4:0] COL = (obj_pxl != 4'h0) ? { 1'b0, obj_pxl } : { 1'b1, tilemap_px };
assign pxl_out = { 2'b00, COL };

endmodule
