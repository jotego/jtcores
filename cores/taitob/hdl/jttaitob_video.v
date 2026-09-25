/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    Author: Andrea Bogazzi.
    Date: 5-2026 */

// ============================================================================
// jttaitob_video — TC0180VCU pipeline (Phase 3b: BG + FG + TX planes)
// ============================================================================
//
// Three tile planes share the same gfx ROM (SDRAM bank 2, 1 MB):
//
//   BG : 64x64 of 16x16 tiles, opaque,        color_base 0xC0, ctrl[1] banks
//   FG : 64x64 of 16x16 tiles, transparent pen 0, color_base 0x80, ctrl[0]
//   TX : 64x32 of 8x8  tiles,  transparent pen 0, color_base 0x00,
//        bank from ctrl[6] high byte, tile-code high bits from ctrl[4]/[5]
//
// VRAM port-B is time-shared with an 8-phase counter (3-bit) covering the
// five fetches each cycle:
//
//   0 → BG code addr        4 → TX code addr
//   1 → BG attr addr        5 → idle (slot for sprite list reads in 3d)
//   2 → FG code addr        6 → idle
//   3 → FG attr addr        7 → idle
//
// Each phase needs 1 clk of BRAM latency, so capture lands on phase+1.
//
// SDRAM bank-2 buses:
//   bg  → BG plane gfx fetches
//   obj → FG plane gfx fetches (sprites take this in Phase 3d)
//   tx  → text plane gfx fetches
//
// Three independent slice-fetch FSMs run in parallel, each with its own
// double-buffer (fetch/render).  At each slice boundary all three buffers
// snap atomically.
//
// Pixel priority (Phase 3b, fixed): TX > FG > BG.  No sprites yet, no
// per-frame priority mode (ctrl[7] bit 3) — Phase 4 wires that.
//
// Tile addressing math:
//
//   BG/FG (16x16, chartsize 64*8 bits per ROM half):
//     byte_offset = {y[3], x[3], y[2:0], 1'b0}
//     word_addr_01 = {tile_code[13:0], y[3], x[3], y[2:0]}
//     word_addr_23 = word_addr_01 + 0x40000
//     bit_idx within byte = x[2:0]
//
//   TX (8x8, chartsize 16*8 bits per ROM half):
//     byte_offset = 2 * y
//     word_addr_01 = {tile_code[11:0], y[2:0]}    (15 bits)
//     word_addr_23 = word_addr_01 + 0x40000
//     bit_idx within byte = x[2:0]
//
// Text tile word layout (read from VRAM at {tx_bank, text_idx}):
//   bits[10:0]  = tile-code low
//   bit [11]    = selects high-bank: 0 → ctrl[4], 1 → ctrl[5]
//   bits[15:12] = palette base offset (added to color_base 0x00)
// Effective tile-code for Nastar's 1 MB TC0180VCU ROM region is
// {high_bank[3:0], tile[10:0]} = 15 bits total.  MAME exposes a wider
// generic bank field because other Taito B sets ship larger gfx regions,
// but this core currently wires a 1 MB bank-2 ROM and must preserve the
// full 15-bit character index within that space.
//
// ============================================================================

module jttaitob_video(
    input               rst,
    input               clk,
    input               pxl_cen,

    input               LHBL,
    input               LVBL,
    input        [ 8:0] vdump,
    input        [ 8:0] vrender,                 // = vdump+1; BG line-buffer fills this line during HBLANK
    input        [ 8:0] hdump,

    input        [127:0] vcu_ctrl,

    // VRAM port-B (shared between BG, FG, TX via 8-phase)
    output reg   [15:0] vram_addr_b,
    input        [15:0] vram_dout_b,

    // Sprite/scroll RAM port-B (Phase 3c: scroll reads at vblank,
    // Phase 3d: sprite-list reads during HBLANK)
    output reg   [12:0] oram_addr_b,
    input        [15:0] oram_dout_b,

    // SDRAM bank-2 buses
    output reg   [18:0] bg_addr,
    output reg          bg_cs,
    input        [15:0] bg_data,
    input               bg_ok,
    output reg   [18:0] obj_addr,
    output reg          obj_cs,
    input        [15:0] obj_data,
    input               obj_ok,
    output reg   [18:0] tx_addr,
    output reg          tx_cs,
    input        [15:0] tx_data,
    input               tx_ok,
    // SDRAM bank-3 bus — FG plane's dedicated gfx copy (interleaves with BG)
    output reg   [18:0] fg_addr,
    output reg          fg_cs,
    input        [15:0] fg_data,
    input               fg_ok,

    output reg   [11:0] pal_idx
);

// ─── Unpack ctrl registers ─────────────────────────────────────────────────
wire [15:0] ctrl0 = vcu_ctrl[ 15:  0];           // FG bank pair
wire [15:0] ctrl1 = vcu_ctrl[ 31: 16];           // BG bank pair
wire [15:0] ctrl4 = vcu_ctrl[ 79: 64];           // TX tile bank 0
wire [15:0] ctrl5 = vcu_ctrl[ 95: 80];           // TX tile bank 1
wire [15:0] ctrl6 = vcu_ctrl[111: 96];           // TX ram page
wire [15:0] ctrl7 = vcu_ctrl[127:112];           // video_control

wire [ 3:0] bg_bank_codes = ctrl1[11: 8];
wire [ 3:0] bg_bank_attrs = ctrl1[15:12];
wire [ 3:0] fg_bank_codes = ctrl0[11: 8];
wire [ 3:0] fg_bank_attrs = ctrl0[15:12];
wire [ 3:0] tx_ram_bank   = ctrl6[11: 8];
wire [ 5:0] tx_high_bank0 = ctrl4[13: 8];        // raw generic TC0180VCU bank field
wire [ 5:0] tx_high_bank1 = ctrl5[13: 8];

// ─── ctrl[7] video_control decode (Phase 4) ───────────────────────────────
//
// Per tc0180vcu.cpp::video_control comments at line 195:
//   bit 0 = don't erase sprite framebuffer "after the beam"
//   bit 3 = sprite-to-foreground priority
//             1 = bg, fg, obj, tx
//             0 = bg, obj1, fg, obj0, tx  (obj selected by tile-color bit 0)
//   bit 4 = screen flip (active HI)
//   bit 5 = global video enable (Hit-the-Ice toggles this around vram clears)
//   bit 6 = framebuffer page to show when bit 7 set
//   bit 7 = don't flip framebuffer every vblank
//
// All operate on the HIGH byte of ctrl[7] (the 68k writes them as byte
// stores to even addresses).
wire        vc_sprite_pri    = ctrl7[11];        // bit 3
wire        vc_screen_flip   = ctrl7[12];        // bit 4
wire        vc_video_enable  = ctrl7[13];        // bit 5

/* verilator lint_off UNUSED */
wire _unused_video = rst | |ctrl0[7:0] | |ctrl1[7:0] | |ctrl4[7:0] |
                     |ctrl5[7:0] | |ctrl6[7:0] |
                     ctrl7[8] | ctrl7[9] | ctrl7[10] |
                     ctrl7[14] | ctrl7[15] | |ctrl7[7:0] |
                     vc_sprite_pri | vc_screen_flip;
/* verilator lint_on UNUSED */

// ─── Scroll RAM read FSM (Phase 3c) ────────────────────────────────────────
//
// At each LVBL falling edge (vblank start) we burst-read 4 words from
// oram-side scroll RAM and latch them:
//
//   oram word 0x1C00 (= byte 0x413800) → fg_scrollx
//   oram word 0x1C01                    → fg_scrolly
//   oram word 0x1E00 (= byte 0x413C00) → bg_scrollx
//   oram word 0x1E01                    → bg_scrolly
//
// This implements the lines_per_block = 256 case (ctrl[2] = ctrl[3] = 0,
// which is exactly what nastar writes at boot).  Per-line scrolling
// (lines_per_block < 256) would require re-reading scrollram during
// the visible scan — Phase 3c+ enhancement.
//
// Each scroll word is treated as signed; the bottom bits wrap naturally
// over the 64-tile (1024 px) plane.

reg [15:0] bg_scrollx, bg_scrolly, fg_scrollx, fg_scrolly;
reg [ 2:0] scroll_fsm;                            // 0=idle, 1..4 = reading
reg [12:0] scr_oram_addr;                         // scroll FSM's oram address
reg        LVBL_d;

always @(posedge clk) begin
    if (rst) begin
        bg_scrollx <= 16'h0; bg_scrolly <= 16'h0;
        fg_scrollx <= 16'h0; fg_scrolly <= 16'h0;
        scroll_fsm <= 3'd0;
        scr_oram_addr <= 13'd0;
        LVBL_d     <= 1'b1;
    end else begin
        LVBL_d <= LVBL;
        // Fix 6: the oram BRAM has a 1-clk read latency (q1 at clk T+1 =
        // mem[addr1 at clk T]).  The old FSM latched each scroll value in
        // the same state it set the address, so it read one address too
        // early — fg_scrollx in particular latched the uninitialised
        // pre-sequence bus value and scrolled FG off-screen into empty
        // tilemap (FG rendered tile 0 everywhere = invisible).  Add one
        // wait state so each value is latched the cycle AFTER its address
        // has settled on the BRAM output.
        case (scroll_fsm)
            3'd0: begin
                scr_oram_addr <= 13'd0;
                // Trigger on vblank entry (LVBL high→low transition)
                if (LVBL_d & ~LVBL) begin
                    scr_oram_addr <= 13'h1C00;     // request FG scrollx
                    scroll_fsm  <= 3'd1;
                end
            end
            3'd1: begin                          // FG scrollx in flight; queue FG scrolly
                scr_oram_addr <= 13'h1C01;
                scroll_fsm  <= 3'd2;
            end
            3'd2: begin                          // latch FG scrollx (= mem[0x1C00])
                fg_scrollx  <= oram_dout_b;
                scr_oram_addr <= 13'h1E00;
                scroll_fsm  <= 3'd3;
            end
            3'd3: begin                          // latch FG scrolly (= mem[0x1C01])
                fg_scrolly  <= oram_dout_b;
                scr_oram_addr <= 13'h1E01;
                scroll_fsm  <= 3'd4;
            end
            3'd4: begin                          // latch BG scrollx (= mem[0x1E00])
                bg_scrollx  <= oram_dout_b;
                scr_oram_addr <= 13'd0;
                scroll_fsm  <= 3'd5;
            end
            3'd5: begin                          // latch BG scrolly (= mem[0x1E01])
                bg_scrolly  <= oram_dout_b;
                scr_oram_addr <= 13'd0;
                scroll_fsm  <= 3'd0;
            end
            default: scroll_fsm <= 3'd0;
        endcase
    end
end

// ─── Sprite engine (Phase 3d) + oram port arbitration ──────────────────────
// The sprite scanner and the scroll FSM share oram port-B.  They never
// overlap (scroll = vblank entry, scanner = visible active lines), so a
// simple priority mux suffices: scanner owns the port while obj_sc_cs is high.
wire [12:0] obj_sc_addr;
wire        obj_sc_cs;
wire [18:0] obj_gfx_addr;
wire        obj_gfx_cs;
wire [11:0] obj_pixel;
wire        obj_visible;

always @* oram_addr_b = obj_sc_cs ? obj_sc_addr : scr_oram_addr;

// obj gfx bus: sprites only. FG used to share this bus (muxed here); it now
// has its own dedicated bus/bank (`fg`, bank 3), so the sprite engine owns
// the obj bus outright — no mux, no FG-vs-sprite contention.
always @* begin
    obj_cs   = obj_gfx_cs;
    obj_addr = obj_gfx_addr;
end

jttaitob_obj u_obj(
    .rst       ( rst         ),
    .clk       ( clk         ),
    .pxl_cen   ( pxl_cen     ),
    .LHBL      ( LHBL        ),
    .LVBL      ( LVBL        ),
    .hdump     ( hdump       ),
    .vrender   ( vrender     ),
    .sc_addr   ( obj_sc_addr ),
    .sc_cs     ( obj_sc_cs   ),
    .sc_data   ( oram_dout_b ),
    .gfx_addr  ( obj_gfx_addr),
    .gfx_cs    ( obj_gfx_cs  ),
    .gfx_data  ( obj_data    ),
    .gfx_ok    ( obj_ok      ),
    .obj_pixel ( obj_pixel   ),
    .obj_visible( obj_visible )
);

// ─── Plane scroll convention ───────────────────────────────────────────────
// Per-plane scrolled coordinates.  The BG/FG planes are 64x64 tiles of
// 16x16 pixels = 1024×1024 px wrap.  Only the bottom 10 bits matter
// (the rest wraps over the 1024-px plane).
//
// MAME applies scroll with set_scrollx(0,-scrollx)/set_scrolly(0,-scrolly)
// (tc0180vcu.cpp tilemap_draw): screen pixel maps to tilemap (pixel -
// scrollram).  So we SUBTRACT the scroll register from the screen
// position; adding it (the old code) scrolled both planes the wrong way.
// scroll values are in pixel units, signed in the chip; wrap is natural.
// (All three planes — BG, FG, TX — are rendered by line-buffer rings filled
// during HBLANK; there is no per-slice look-ahead any more.)

// ─── VRAM port-B arbitration ─────────────────────────────────────────────────
// The three HBLANK ring fills share VRAM port-B in priority order BG -> FG ->
// TX (they run back-to-back inside HBLANK; none of them render during it).
always @* begin
    if      (bg_fill_busy) vram_addr_b = bg_fill_vaddr;
    else if (fg_fill_busy) vram_addr_b = fg_fill_vaddr;
    else if (tx_fill_busy) vram_addr_b = tx_fill_vaddr;
    else                   vram_addr_b = 16'd0;
end

// ─── gfx_sort address swap ──────────────────────────────────────────────────
// mem.yaml applies gfx_sort=hvvvx (mode gfx4, b0=1) to the gfx region: it
// rotates gfx-word address bits [3:0] as {b3->b0, b0->b1, b1->b2, b2->b3},
// i.e. the tilelayout L/R-8px-half bit (px3, word bit 3) becomes the LSB so a
// tile-row's two halves sit at adjacent addresses (read-cache hit on the 2nd).
// Every gfx address the HDL generates must therefore be remapped the same way:
//   sorted = {A[18:4], A[2:0], A[3]}
// The 0x40000 plane-pair offset is bit 18 (outside the swapped window), so it
// is added AFTER the swap and is unaffected.  Word data is untouched → decode
// is unchanged.  TX (8x8) doesn't gain from the swap but must use it to read
// the (now reordered) shared region correctly.
function [18:0] gsort;
    input [18:0] a;
    gsort = {a[18:4], a[2:0], a[3]};
endfunction

// ════════════════════════════════════════════════════════════════════════
// BG plane — full-line decoded-pixel buffer (jttaitob_shifter ring)
// ════════════════════════════════════════════════════════════════════════
// During HBLANK the upcoming scanline's BG tile-row is decoded into a 32-slot
// ring (one 16-px tile per slot; slot = plane tile-col mod 32, a 512-px
// window that covers the 320-px line with no slot aliasing).  During active
// the renderer reads it with tap = (hdump - bg_scrollx), so sub-tile (fine)
// horizontal scroll and tile-boundary straddles need no per-slice handling.
// The fill borrows the VRAM port for code/attr (FG/TX don't render in HBLANK)
// and reads gfx from the dedicated bg bus.  vrender (= vdump+1) is the line.
localparam [5:0] BG_NTILES = 6'd22;     // tiles per line (320px + margin)

// Fill line is LATCHED once at fill-kick (fill_line) and frozen for the
// whole fill.  The fill runs during line N's HBLANK and is read on the next
// active line (N+1); at kick vdump==N so we latch vrender (= N+1).  Latching
// is essential, not cosmetic: vdump increments mid-HBLANK (at HS_START=340,
// inside the gfx_sort-shortened fill window hdump 321..367), so a combinational
// vrender flips N+1->N+2 partway through and fills early columns one row off
// from late columns — the "first 19 cols 1px, last col 1px the other way"
// symptom.  Freezing the line at kick makes every column use the same row.
reg  [ 7:0] fill_line;
wire [ 9:0] bg_fill_eff_y = {2'b0, fill_line} - bg_scrolly[9:0];
wire [ 5:0] bg_fill_ty    = bg_fill_eff_y[9:4];
wire [ 3:0] bg_fill_row   = bg_fill_eff_y[3:0];
wire [ 9:0] bg_col0       = 10'd0 - bg_scrollx[9:0];   // leftmost visible tile @hdump=0

reg  [ 3:0] bg_fst;                     // fill sub-state
reg  [ 5:0] bg_fcnt;                    // tiles loaded this line
reg  [ 5:0] bg_fcol;                    // plane tile-column being filled (0..63)
reg  [15:0] bg_fcode, bg_fattr;
reg  [15:0] bg_w01l, bg_w23l, bg_w01r;
reg         bg_fill_busy;               // owns VRAM port while high
reg         bg_ring_load;
reg  [ 4:0] bg_ring_lidx;
reg  [63:0] bg_ring_pix;
reg  [11:0] bg_ring_pal;
reg         bg_ring_flip;
reg         LHBL_dly;

wire        bg_fflipx = bg_fattr[6];
wire        bg_fflipy = bg_fattr[7];
wire [ 3:0] bg_frow_e = bg_fflipy ? ~bg_fill_row : bg_fill_row;
wire [11:0] bg_fpal   = {(8'hC0 + {2'b00, bg_fattr[5:0]}), 4'b0000};
wire [18:0] bg_fw01l  = gsort({bg_fcode[13:0], bg_frow_e[3], 1'b0, bg_frow_e[2:0]});
wire [18:0] bg_fw01r  = gsort({bg_fcode[13:0], bg_frow_e[3], 1'b1, bg_frow_e[2:0]});
wire [18:0] bg_fw23l  = bg_fw01l + 19'h40000;
wire [18:0] bg_fw23r  = bg_fw01r + 19'h40000;
wire [15:0] bg_fcode_addr = { bg_bank_codes[3:0], {bg_fill_ty, bg_fcol} };
wire [15:0] bg_fattr_addr = { bg_bank_attrs[3:0], {bg_fill_ty, bg_fcol} };
// VRAM address this FSM drives (code, then attr); arbitrated into vram_addr_b.
wire [15:0] bg_fill_vaddr = (bg_fst==4'd2) ? bg_fattr_addr : bg_fcode_addr;
wire        bg_fill_kick  = LHBL_dly & ~LHBL;          // enter HBLANK

// One 4bpp pen of the current fill tile (normal order; flipX applied at load).
// pen p: half=p[3], bit=~p[2:0]; pen = {w01lo,w01hi,w23lo,w23hi}[bit] — the
// verified plane/byte order from the per-slice renderer.
function [3:0] bg_pen;
    input [ 3:0] p;
    input [15:0] w01l, w23l, w01r, w23r;
    reg   [ 3:0] b;
    reg   [15:0] w01, w23;
    begin
        b   = {1'b0, ~p[2:0]};            // 0..7, 4-bit index into the 16-bit word
        w01 = p[3] ? w01r : w01l;
        w23 = p[3] ? w23r : w23l;
        bg_pen = { w01[b], w01[b+4'd8], w23[b], w23[b+4'd8] };
    end
endfunction

integer bp;
always @(posedge clk) begin
    if (rst) begin
        bg_fst <= 4'd0; bg_fcnt <= 6'd0; bg_fcol <= 6'd0;
        bg_cs <= 1'b0; bg_addr <= 19'd0;
        bg_fill_busy <= 1'b0; bg_ring_load <= 1'b0; LHBL_dly <= 1'b1;
        fill_line <= 8'd0;
    end else begin
        LHBL_dly     <= LHBL;
        bg_ring_load <= 1'b0;
        case (bg_fst)
        4'd0: begin                                     // idle until HBLANK
            bg_cs <= 1'b0; bg_fill_busy <= 1'b0;
            if (bg_fill_kick) begin
                bg_fcnt <= 6'd0; bg_fcol <= bg_col0[9:4];
                fill_line <= vrender[7:0];           // freeze fill line (N+1) for the whole fill
                bg_fill_busy <= 1'b1; bg_fst <= 4'd1;
            end
        end
        4'd1: bg_fst <= 4'd2;                            // code addr on bus, settling
        4'd2: begin bg_fcode <= vram_dout_b; bg_fst <= 4'd3; end // capture code; attr addr now driven
        4'd3: begin bg_fattr <= vram_dout_b; bg_fst <= 4'd4; end // capture attr
        4'd4: begin bg_cs <= 1'b1; bg_addr <= bg_fw01l; bg_fst <= 4'd5; end
        4'd5: if (bg_ok) begin bg_w01l <= bg_data; bg_addr <= bg_fw23l; bg_fst <= 4'd6; end
        4'd6: if (bg_ok) begin bg_w23l <= bg_data; bg_addr <= bg_fw01r; bg_fst <= 4'd7; end
        4'd7: if (bg_ok) begin bg_w01r <= bg_data; bg_addr <= bg_fw23r; bg_fst <= 4'd8; end
        4'd8: if (bg_ok) begin                          // bg_data = w23r
            for (bp = 0; bp < 16; bp = bp + 1)
                bg_ring_pix[4*bp +: 4] <= bg_pen(bp[3:0], bg_w01l, bg_w23l, bg_w01r, bg_data);
            bg_ring_pal  <= bg_fpal;
            bg_ring_flip <= bg_fflipx;
            bg_ring_lidx <= bg_fcol[4:0];
            bg_ring_load <= 1'b1;
            bg_cs   <= 1'b0;
            bg_fcol <= bg_fcol + 6'd1;
            bg_fcnt <= bg_fcnt + 6'd1;
            bg_fst  <= ((bg_fcnt + 6'd1) >= BG_NTILES) ? 4'd0 : 4'd1;
        end
        default: bg_fst <= 4'd0;
        endcase
    end
end

// BG ring + fine-scroll read tap.
// +1: the shifter registers pen_out/pal_out on pxl_cen, so the BG read-out
// carries one extra pixel of latency that the (combinational) FG path does
// not.  With FG verified pixel-aligned to MAME, BG was landing 1px to the
// right; advancing the tap by one pixel cancels that register delay.
//
// During HBLANK clamp the tap's hdump to 0 so it stays on the leftmost
// visible tile instead of walking off into unfilled ring slots.  The shifter
// then has the leftmost pixel registered by the first active pixel, priming
// pal_idx@hdump0 — otherwise the registered read-out carried a 0 from an
// unfilled slot into the first pixel (the 1px black left-edge artifact).
// Active region (hdump 0..319) is unaffected.
wire [ 8:0] bg_draw_hd = (hdump < 9'd320) ? hdump[8:0] : 9'd0;
wire [ 9:0] bg_draw_x  = {1'b0, bg_draw_hd} - bg_scrollx[9:0] + 10'd1;
wire [11:0] bg_idx;
wire [ 3:0] bg_pen_out;
jttaitob_shifter #(.TW(16), .LEN(32)) u_bg_ring(
    .clk        ( clk          ),
    .ce         ( pxl_cen      ),
    .load       ( bg_ring_load ),
    .load_index ( bg_ring_lidx ),
    .load_pal   ( bg_ring_pal  ),
    .load_pix   ( bg_ring_pix  ),
    .load_flip  ( bg_ring_flip ),
    .tap        ( bg_draw_x[8:0] ),
    .pal_out    ( bg_idx       ),
    .pen_out    ( bg_pen_out   )
);
wire [11:0] bg_pix_idx = bg_idx | {8'h0, bg_pen_out};

// ════════════════════════════════════════════════════════════════════════
// FG plane — full-line ring (Step 2: was per-slice).  Same structure as BG.
// ════════════════════════════════════════════════════════════════════════
// Fills the upcoming line's FG tile-row into u_fg_ring during HBLANK, AFTER
// the BG fill finishes (they serialize on the shared VRAM port; FG gfx comes
// from the obj bus).  Read during active with tap = hdump - fg_scrollx, so
// fine (mod-8) horizontal scroll is handled for free — this deletes the
// per-slice fetch_start / copy-pending band-aids.  Uses the SAME frozen
// fill_line as BG (latched at bg_fill_kick) so the mid-HBLANK vdump increment
// can't split the fill across columns.
wire [ 9:0] fg_fill_eff_y = {2'b0, fill_line} - fg_scrolly[9:0];
wire [ 5:0] fg_fill_ty    = fg_fill_eff_y[9:4];
wire [ 3:0] fg_fill_row   = fg_fill_eff_y[3:0];
wire [ 9:0] fg_col0       = 10'd0 - fg_scrollx[9:0];

reg  [ 3:0] fg_fst;
reg  [ 5:0] fg_fcnt;
reg  [ 5:0] fg_fcol;
reg  [15:0] fg_fcode, fg_fattr;
reg  [15:0] fg_w01l, fg_w23l, fg_w01r;
reg         fg_fill_busy;
reg         fg_ring_load;
reg  [ 4:0] fg_ring_lidx;
reg  [63:0] fg_ring_pix;
reg  [11:0] fg_ring_pal;
reg         fg_ring_flip;
reg         bg_busy_q;
// FG fill drives the dedicated `fg` bus (bank 3) — fg_addr/fg_cs are module
// output ports now, no longer muxed onto the obj bus.

wire        fg_fflipx = fg_fattr[6];
wire        fg_fflipy = fg_fattr[7];
wire [ 3:0] fg_frow_e = fg_fflipy ? ~fg_fill_row : fg_fill_row;
wire [11:0] fg_fpal   = {(8'h80 + {2'b00, fg_fattr[5:0]}), 4'b0000};
wire [18:0] fg_fw01l  = gsort({fg_fcode[13:0], fg_frow_e[3], 1'b0, fg_frow_e[2:0]});
wire [18:0] fg_fw01r  = gsort({fg_fcode[13:0], fg_frow_e[3], 1'b1, fg_frow_e[2:0]});
wire [18:0] fg_fw23l  = fg_fw01l + 19'h40000;
wire [18:0] fg_fw23r  = fg_fw01r + 19'h40000;
wire [15:0] fg_fcode_addr = { fg_bank_codes[3:0], {fg_fill_ty, fg_fcol} };
wire [15:0] fg_fattr_addr = { fg_bank_attrs[3:0], {fg_fill_ty, fg_fcol} };
wire [15:0] fg_fill_vaddr = (fg_fst==4'd2) ? fg_fattr_addr : fg_fcode_addr;
wire        fg_fill_kick  = bg_busy_q & ~bg_fill_busy;   // BG fill just finished

integer fp;
always @(posedge clk) begin
    if (rst) begin
        fg_fst <= 4'd0; fg_fcnt <= 6'd0; fg_fcol <= 6'd0;
        fg_cs <= 1'b0; fg_addr <= 19'd0;
        fg_fill_busy <= 1'b0; fg_ring_load <= 1'b0; bg_busy_q <= 1'b0;
    end else begin
        bg_busy_q    <= bg_fill_busy;
        fg_ring_load <= 1'b0;
        case (fg_fst)
        4'd0: begin
            fg_cs <= 1'b0; fg_fill_busy <= 1'b0;
            if (fg_fill_kick) begin
                fg_fcnt <= 6'd0; fg_fcol <= fg_col0[9:4];
                fg_fill_busy <= 1'b1; fg_fst <= 4'd1;
            end
        end
        4'd1: fg_fst <= 4'd2;
        4'd2: begin fg_fcode <= vram_dout_b; fg_fst <= 4'd3; end
        4'd3: begin fg_fattr <= vram_dout_b; fg_fst <= 4'd4; end
        4'd4: begin fg_cs <= 1'b1; fg_addr <= fg_fw01l; fg_fst <= 4'd5; end
        4'd5: if (fg_ok) begin fg_w01l <= fg_data; fg_addr <= fg_fw23l; fg_fst <= 4'd6; end
        4'd6: if (fg_ok) begin fg_w23l <= fg_data; fg_addr <= fg_fw01r; fg_fst <= 4'd7; end
        4'd7: if (fg_ok) begin fg_w01r <= fg_data; fg_addr <= fg_fw23r; fg_fst <= 4'd8; end
        4'd8: if (fg_ok) begin                          // fg_data = w23r
            for (fp = 0; fp < 16; fp = fp + 1)
                fg_ring_pix[4*fp +: 4] <= bg_pen(fp[3:0], fg_w01l, fg_w23l, fg_w01r, fg_data);
            fg_ring_pal  <= fg_fpal;
            fg_ring_flip <= fg_fflipx;
            fg_ring_lidx <= fg_fcol[4:0];
            fg_ring_load <= 1'b1;
            fg_cs  <= 1'b0;
            fg_fcol <= fg_fcol + 6'd1;
            fg_fcnt <= fg_fcnt + 6'd1;
            fg_fst  <= ((fg_fcnt + 6'd1) >= BG_NTILES) ? 4'd0 : 4'd1;
        end
        default: fg_fst <= 4'd0;
        endcase
    end
end

// FG ring + fine-scroll read tap (same clamp/+1 as BG).
wire [ 8:0] fg_draw_hd = (hdump < 9'd320) ? hdump[8:0] : 9'd0;
wire [ 9:0] fg_draw_x  = {1'b0, fg_draw_hd} - fg_scrollx[9:0] + 10'd1;
wire [11:0] fg_idx;
wire [ 3:0] fg_pen_out;
jttaitob_shifter #(.TW(16), .LEN(32)) u_fg_ring(
    .clk        ( clk          ),
    .ce         ( pxl_cen      ),
    .load       ( fg_ring_load ),
    .load_index ( fg_ring_lidx ),
    .load_pal   ( fg_ring_pal  ),
    .load_pix   ( fg_ring_pix  ),
    .load_flip  ( fg_ring_flip ),
    .tap        ( fg_draw_x[8:0] ),
    .pal_out    ( fg_idx       ),
    .pen_out    ( fg_pen_out   )
);
wire        fg_visible = |fg_pen_out;
wire [11:0] fg_pix_idx = fg_idx | {8'h0, fg_pen_out};

// ════════════════════════════════════════════════════════════════════════
// TX plane — full-line ring (8x8 tiles).  Same approach as BG/FG.
// ════════════════════════════════════════════════════════════════════════
// 8x8 text tiles, no scroll, no flip.  ONE VRAM word per tile carries
// {pal[15:12], hi[11], code[10:0]}.  Filled during HBLANK after the FG fill;
// gfx on the tx bus.  TW=8, LEN=64 (full plane width; tap = hdump indexes it).
// Reuses gsort + bg_pen + the shared frozen fill_line.  No scroll, so col0=0.
localparam [6:0] TX_NTILES = 7'd42;     // 8px tiles to cover 320px + margin

wire [ 4:0] tx_fill_ty  = fill_line[7:3];
wire [ 2:0] tx_fill_row = fill_line[2:0];

reg  [ 3:0] tx_fst;
reg  [ 6:0] tx_fcnt;
reg  [ 5:0] tx_fcol;                    // plane tile-column (0..63)
reg  [15:0] tx_fword;                   // captured VRAM word (pal/hi/code)
reg  [15:0] tx_w01;
reg         tx_fill_busy;
reg         tx_ring_load;
reg  [ 5:0] tx_ring_lidx;
reg  [31:0] tx_ring_pix;                // 8 px * 4bpp
reg  [11:0] tx_ring_pal;
reg         fg_busy_q;

wire [ 3:0] tx_fhigh = tx_fword[11] ? tx_high_bank1[3:0] : tx_high_bank0[3:0];
wire [14:0] tx_fcode = {tx_fhigh, tx_fword[10:0]};
wire [11:0] tx_fpal  = {(8'h00 + {4'b0000, tx_fword[15:12]}), 4'b0000};
wire [18:0] tx_fw01  = gsort({1'b0, tx_fcode, tx_fill_row});
wire [18:0] tx_fw23  = tx_fw01 + 19'h40000;
wire [15:0] tx_fill_vaddr = { 1'b0, tx_ram_bank[3:0], tx_fill_ty, tx_fcol };
wire        tx_fill_kick  = fg_busy_q & ~fg_fill_busy;   // FG fill just finished

integer tp;
always @(posedge clk) begin
    if (rst) begin
        tx_fst <= 4'd0; tx_fcnt <= 7'd0; tx_fcol <= 6'd0;
        tx_cs <= 1'b0; tx_addr <= 19'd0;
        tx_fill_busy <= 1'b0; tx_ring_load <= 1'b0; fg_busy_q <= 1'b0;
    end else begin
        fg_busy_q    <= fg_fill_busy;
        tx_ring_load <= 1'b0;
        case (tx_fst)
        4'd0: begin
            tx_cs <= 1'b0; tx_fill_busy <= 1'b0;
            if (tx_fill_kick) begin
                tx_fcnt <= 7'd0; tx_fcol <= 6'd0;       // no scroll → start at col 0
                tx_fill_busy <= 1'b1; tx_fst <= 4'd1;
            end
        end
        4'd1: tx_fst <= 4'd2;                            // tx_word addr settling
        4'd2: begin tx_fword <= vram_dout_b; tx_fst <= 4'd3; end   // capture tx_word
        4'd3: begin tx_cs <= 1'b1; tx_addr <= tx_fw01; tx_fst <= 4'd4; end
        4'd4: if (tx_ok) begin tx_w01 <= tx_data; tx_addr <= tx_fw23; tx_fst <= 4'd5; end
        4'd5: if (tx_ok) begin                          // tx_data = w23
            for (tp = 0; tp < 8; tp = tp + 1)
                tx_ring_pix[4*tp +: 4] <= bg_pen({1'b0, tp[2:0]}, tx_w01, tx_data, tx_w01, tx_data);
            tx_ring_pal  <= tx_fpal;
            tx_ring_lidx <= tx_fcol;
            tx_ring_load <= 1'b1;
            tx_cs   <= 1'b0;
            tx_fcol <= tx_fcol + 6'd1;
            tx_fcnt <= tx_fcnt + 7'd1;
            tx_fst  <= ((tx_fcnt + 7'd1) >= TX_NTILES) ? 4'd0 : 4'd1;
        end
        default: tx_fst <= 4'd0;
        endcase
    end
end

// ─── SIM: HBLANK fill-budget overrun detector ─────────────────────────────
// The BG→FG→TX ring fills run sequentially during HBLANK. If any is still
// busy when active resumes (LHBL rising), the fill overran the blank — the
// tell-tale of a too-short H-blank (e.g. after dropping PXLCLK 8→6).
`ifdef SIMULATION
reg lhbl_q2;
integer fill_overruns = 0;
always @(posedge clk) begin
    lhbl_q2 <= LHBL;
    if (LHBL & ~lhbl_q2 && LVBL) begin           // HBLANK→active edge, visible field
        if (bg_fill_busy | fg_fill_busy | tx_fill_busy) begin
            fill_overruns = fill_overruns + 1;
            $display("[FILL-OVERRUN #%0d] vrender=%0d at active start: bg=%b fg=%b tx=%b",
                     fill_overruns, vrender, bg_fill_busy, fg_fill_busy, tx_fill_busy);
        end
    end
end
final $display("[FILL-OVERRUN] total overrunning lines = %0d", fill_overruns);
`endif

// TX ring + read tap (no scroll; +1 cancels the shifter register, HBLANK clamp).
wire [ 8:0] tx_draw_hd = (hdump < 9'd320) ? hdump[8:0] : 9'd0;
wire [ 8:0] tx_draw_x  = tx_draw_hd + 9'd1;
wire [11:0] tx_idx;
wire [ 3:0] tx_pen_out;
jttaitob_shifter #(.TW(8), .LEN(64)) u_tx_ring(
    .clk        ( clk          ),
    .ce         ( pxl_cen      ),
    .load       ( tx_ring_load ),
    .load_index ( tx_ring_lidx ),
    .load_pal   ( tx_ring_pal  ),
    .load_pix   ( tx_ring_pix  ),
    .load_flip  ( 1'b0         ),
    .tap        ( tx_draw_x    ),
    .pal_out    ( tx_idx       ),
    .pen_out    ( tx_pen_out   )
);
wire        tx_visible = |tx_pen_out;
wire [11:0] tx_pix_idx = tx_idx | {8'h0, tx_pen_out};

// ─── Priority MUX (Phase 3b fixed order: TX > FG > BG) ─────────────────────
// Emit the 12-bit palette INDEX.  Colmix owns the palette-RAM lookup AND the
// LHBL/LVBL blanking, so we do NOT blank pal_idx here: gating it on the raw
// (1px-lagging) LHBL added a redundant register stage that forced the first
// active pixels to 0 even though bg_pix_idx was already valid — the 1-2px
// black left-edge artifact.  Always emit the real pixel; colmix blanks.
always @(posedge clk) begin
    if (pxl_cen) begin
        pal_idx <= tx_visible  ? tx_pix_idx :
                   obj_visible ? obj_pixel  :       // Phase 3d: sprites (mode 1: bg<fg<obj<tx)
                   fg_visible  ? fg_pix_idx :
                                 bg_pix_idx;
    end
end

/* verilator lint_off UNUSED */
wire _unused_p3b = |vdump |
                   |bg_scrollx[15:10] | |bg_scrolly[15:10] |
                   |fg_scrollx[15:10] | |fg_scrolly[15:10] |
                   |bg_col0[3:0] | |fg_col0[3:0] | vrender[8];
/* verilator lint_on UNUSED */

endmodule
