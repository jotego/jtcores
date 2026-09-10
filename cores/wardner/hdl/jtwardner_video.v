/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Wardner video: three scrolling tilemaps, a sprite line buffer and the
 * priority mixer, all driven from a 7 MHz pixel enable.
 *
 * The raster is the one the game programs into its HD6845S: 446 pixels per
 * line, 320 visible, 286 lines per frame, 240 visible (54.878 Hz).
 *
 * Layer semantics follow MAME's twincobr_v.cpp / toaplan_scu.cpp, which is
 * the reference the bench diffs against:
 *   - a tilemap pixel at screen (x,y) comes from pixmap column x+55+scrollx
 *     and row y+30+scrolly, wrapping at the map size;
 *   - the background is opaque, foreground and text are transparent on pen 0;
 *   - sprites are ordered so that entry 0 ends on top. A sprite pixel is
 *     hidden by the foreground and text layers according to its 2-bit
 *     priority, but only where it is the first sprite to touch that pixel:
 *     MAME marks every touched pixel as priority 31 whether it drew or not,
 *     after which nothing blocks later sprites there. The line buffer keeps a
 *     "multi" bit per pixel to reproduce that.
 *
 * Sprites are taken from a copy of the object RAM made when vertical
 * blanking starts, like the buffered sprite RAM on the board.
 *
 * Pipeline: a pixel's layer data is valid while hdump holds its position;
 * the mixer registers the palette address on the next pixel enable and the
 * colour on the one after, so red/green/blue lag hdump by two pixels.
 *
 * Screen flip mirrors the three tilemaps, as MAME's flipscreen_w does by
 * setting TILEMAP_FLIPX|TILEMAP_FLIPY on all of them. Mirroring the pixmap
 * and switching to the second scroll offsets (-134, -243) collapses into one
 * coordinate remap, so only the traversal direction changes: see the note in
 * jtwardner_tile. Sprites are left alone, because the sprite generator never
 * reads the screen flip - MAME's behaviour, which the bench diffs against.
 */

module jtwardner_video(
    input             rst,
    input             clk,
    input             pxl_cen,          // 7 MHz

    // registers from the main CPU
    input      [15:0] tx_scrx, tx_scry, bg_scrx, bg_scry, fg_scrx, fg_scry,
    input             flip, bg_bank, fg_bank, video_on,
    input      [ 3:0] gfx_en,           // OSD debug: 0 text, 1 bg, 2 fg, 3 sprites

    // video RAM read ports (registered, one clock of latency)
    output     [10:0] tx_vaddr,  input [15:0] tx_vq,
    output     [12:0] bg_vaddr,  input [15:0] bg_vq,
    output     [11:0] fg_vaddr,  input [15:0] fg_vq,
    output reg [10:0] pal_vaddr, input [15:0] pal_vq,
    output     [10:0] obj_vaddr, input [15:0] obj_vq,

    // graphics ROMs: one tile row per 32-bit word, a byte per plane (byte 0 is
    // plane 0), MSB is the leftmost pixel. Address is {tile, row} for 8x8
    // tiles and {sprite, row, half} for 16x16 sprites. rom_ok must drop as
    // soon as the address changes and rise once the data matches it.
    output     [13:0] char_addr, input [31:0] char_data, output char_cs, input char_ok,
    output     [15:0] fg_addr,   input [31:0] fg_data,   output fg_cs,   input fg_ok,
    output     [14:0] bg_addr,   input [31:0] bg_data,   output bg_cs,   input bg_ok,
    output     [15:0] obj_addr,  input [31:0] obj_data,  output obj_cs,  input obj_ok,

    output            LVBL, LHBL, HS, VS,
    output     [ 8:0] hdump, vdump,
    output reg [ 4:0] red, green, blue,
    output            obj_ovf           // a line ran out of sprite time (sticky)
);

wire [8:0] vrender, vrender1;
wire       Hinit, Vinit;

// ---- raster
jtframe_vtimer #(
    .HB_START ( 9'd319 ), .HB_END   ( 9'd445 ), .HCNT_END ( 9'd445 ),
    .HS_START ( 9'd352 ), .HS_END   ( 9'd382 ),
    .VB_START ( 9'd239 ), .VB_END   ( 9'd285 ), .VCNT_END ( 9'd285 ),
    .VS_START ( 9'd248 ), .VS_END   ( 9'd256 )
) u_vtimer(
    .clk      ( clk       ), .pxl_cen  ( pxl_cen   ),
    .vdump    ( vdump     ), .vrender  ( vrender   ), .vrender1 ( vrender1  ),
    .H        ( hdump     ), .Hinit    ( Hinit     ), .Vinit    ( Vinit     ),
    .LHBL     ( LHBL      ), .LVBL     ( LVBL      ), .HS       ( HS        ),
    .VS       ( VS        )
);

// The tile engines run over the visible 320 pixels and the last 16 counts of
// the blanking, so the first tile of a line is ready before it is needed.
// heff is the horizontal position as the engines see it, -16..319 (mod 512).
wire [8:0] heff = hdump >= 9'd430 ? hdump - 9'd446 : hdump;
wire       hact = hdump <  9'd320 || hdump >= 9'd430;

// ---- tilemaps, each pixel is {palette, pen}
wire [7:0] bg_pxl, fg_pxl;
wire [8:0] tx_pxl;

jtwardner_tile #(.VA(13),.MAP_VW(9),.CW(12),.PALW(4),.ROMAW(15),.BANK_VRAM(1)) u_bg(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .hact(hact),
    .heff(heff), .vdump(vdump), .scrx(bg_scrx[8:0]), .scry(bg_scry[8:0]),
    .flip(flip), .bank(bg_bank), .vram_addr(bg_vaddr), .vram_q(bg_vq),
    .rom_addr(bg_addr), .rom_data(bg_data), .rom_cs(bg_cs), .rom_ok(bg_ok),
    .pxl(bg_pxl)
);
// the foreground bank selects tiles 4096-8191, which Wardner does not have;
// the ROM wraps the address the way MAME's code % total does
jtwardner_tile #(.VA(12),.MAP_VW(9),.CW(12),.PALW(4),.ROMAW(16),.BANK_CODE(1)) u_fg(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .hact(hact),
    .heff(heff), .vdump(vdump), .scrx(fg_scrx[8:0]), .scry(fg_scry[8:0]),
    .flip(flip), .bank(fg_bank), .vram_addr(fg_vaddr), .vram_q(fg_vq),
    .rom_addr(fg_addr), .rom_data(fg_data), .rom_cs(fg_cs), .rom_ok(fg_ok),
    .pxl(fg_pxl)
);
jtwardner_tile #(.VA(11),.MAP_VW(8),.CW(11),.PALW(5),.ROMAW(14),.BPP(3)) u_tx(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .hact(hact),
    .heff(heff), .vdump(vdump), .scrx(tx_scrx[8:0]), .scry(tx_scry[7:0]),
    .flip(flip), .bank(1'b0), .vram_addr(tx_vaddr), .vram_q(tx_vq),
    .rom_addr(char_addr), .rom_data(char_data), .rom_cs(char_cs), .rom_ok(char_ok),
    .pxl(tx_pxl)
);

// ---- sprites
wire [12:0] obj_pxl;                    // {multi, prio[1:0], colour[5:0], pen[3:0]}

jtwardner_obj u_obj(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .LVBL(LVBL), .hdump(hdump), .vrender(vrender),
    .ram_addr(obj_vaddr), .ram_q(obj_vq),
    .rom_addr(obj_addr), .rom_data(obj_data), .rom_cs(obj_cs), .rom_ok(obj_ok),
    .pxl(obj_pxl), .ovf(obj_ovf)
);

// ---- mixer, then palette
//
// gfx_en comes from JTFRAME's OSD debug menu and switches a layer off without
// changing anything else, which is the only way to tell the layers apart on
// real hardware. jtframe's convention is 0 char/text, 1 first scroll, 2 second
// scroll, 3 objects. A disabled layer reports "no pixel here", so the mixer
// falls through to whatever is behind it exactly as it would if the layer were
// blank.
wire fg_hit  = fg_pxl[3:0]  != 4'd0 && gfx_en[2];
wire tx_hit  = tx_pxl[2:0]  != 3'd0 && gfx_en[0];   // characters have three planes
wire obj_hit = obj_pxl[3:0] != 4'd0 && gfx_en[3];
wire [1:0] obj_prio  = obj_pxl[11:10];
wire       obj_multi = obj_pxl[12];

// MAME pmasks: prio 1 hidden by fg or text, 2 by text, 3 never; a pixel a
// previous sprite touched is never hidden
wire obj_show = obj_hit && (
        obj_multi || obj_prio == 2'd3 ||
        (obj_prio == 2'd2 && !tx_hit) ||
        (obj_prio == 2'd1 && !tx_hit && !fg_hit) );

reg blank_l;

always @(posedge clk) if( pxl_cen ) begin
    // palette bases: sprites 0, bg 1024, fg 1280, text 1536
    // the background is opaque, so switching it off shows palette entry 0 of
    // its bank rather than falling through to anything
    pal_vaddr <= obj_show ? {1'b0, obj_pxl[9:0]} :
                 tx_hit   ? {3'b110, tx_pxl[8:4], tx_pxl[2:0]} :
                 fg_hit   ? {3'b101, fg_pxl}     :
                            {3'b100, gfx_en[1] ? bg_pxl : 8'd0};
    blank_l   <= ~(LVBL & LHBL) | ~video_on;
    // the palette read is one clock, so pal_vq now belongs to the pixel
    // registered at the previous enable
    {blue, green, red} <= blank_l ? 15'd0 : pal_vq[14:0];   // xBGR_555
end

endmodule

// ---------------------------------------------------------------------------
// One tilemap layer, 64 tiles wide and 2^MAP_VW pixels high. While the
// current tile is shown from `cur`, the next one along the row is fetched
// into `nxt`: the VRAM word first, then the ROM row it selects.
module jtwardner_tile #(parameter
    VA=12, MAP_VW=9, CW=12, PALW=4, ROMAW=15, BPP=4,
    BANK_VRAM=0,   // bank bit is the VRAM address MSB (background)
    BANK_CODE=0    // bank bit extends the tile code (foreground)
)(
    input             rst, clk, pxl_cen, hact,
    input      [ 8:0] heff, vdump,
    input      [ 8:0] scrx,
    input [MAP_VW-1:0] scry,
    input             flip,
    input             bank,
    output reg [VA-1:0] vram_addr,
    input      [15:0] vram_q,
    output reg [ROMAW-1:0] rom_addr,
    input      [31:0] rom_data,
    output reg        rom_cs,
    input             rom_ok,
    output [PALW+3:0] pxl
);

// Where the pixel at screen position (heff, vdump) sits in the unflipped
// pixmap. Flipping mirrors the map end to end and swaps in MAME's second
// scroll offsets; folding both into the coordinate leaves the map size out of
// the result (see render_ref.py for the derivation), so the only difference
// is that the scan now walks the map backwards.
wire [8:0] py9 = flip ? (9'd482 + {{(9-MAP_VW){1'b0}}, scry} - vdump)
                      : (vdump + 9'd30 + {{(9-MAP_VW){1'b0}}, scry});

wire [8:0]        px = flip ? (9'd453 + scrx - heff) : (heff + 9'd55 + scrx);
wire [MAP_VW-1:0] py = py9[MAP_VW-1:0];
wire [5:0]        col_nxt = flip ? px[8:3] - 6'd1 : px[8:3] + 6'd1;
// first and last pixel of a tile in scan order, which swap when flipped
wire [2:0]        px_first = flip ? 3'd7 : 3'd0;
wire [2:0]        px_last  = flip ? 3'd0 : 3'd7;

reg [31:0]     cur, nxt;
reg [PALW-1:0] cur_pal, nxt_pal;
reg [ 2:0]     st;
reg [15:0]     code;

// leftmost pixel is the MSB of each plane byte
wire [2:0] sh = ~px[2:0];
wire [7:0] cur3 = cur[31:24], cur2 = cur[23:16], cur1 = cur[15:8], cur0 = cur[7:0];
// MAME's gfx_layout lists planeoffset from the most significant pen bit down:
// charlayout's { RGN_FRAC(0,3), RGN_FRAC(1,3), RGN_FRAC(2,3) } makes the first
// slice of the region pen bit 2, not bit 0, and tilelayout and the SCU's
// spritelayout do the same with four planes. The ROM keeps the region order in
// the low byte, so the pen is assembled from cur0 downwards, not upwards.
wire [3:0] pen = BPP==3 ? { 1'b0, cur0[sh], cur1[sh], cur2[sh] }
                        : {       cur0[sh], cur1[sh], cur2[sh], cur3[sh] };
assign pxl = { cur_pal, pen };

wire [VA-1:0]    vaddr_nxt;
wire [ROMAW-1:0] raddr;
generate
    if( BANK_VRAM ) begin : gen_vram_bank
        assign vaddr_nxt = { bank, py[MAP_VW-1:3], col_nxt };
    end else begin : gen_vram_plain
        assign vaddr_nxt = {       py[MAP_VW-1:3], col_nxt };
    end
    if( BANK_CODE ) begin : gen_code_bank
        assign raddr = { bank, code[CW-1:0], py[2:0] };
    end else begin : gen_code_plain
        assign raddr = {       code[CW-1:0], py[2:0] };
    end
endgenerate

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st <= 0; rom_cs <= 0; cur <= 0; nxt <= 0; cur_pal <= 0; nxt_pal <= 0;
        code <= 0; vram_addr <= 0; rom_addr <= 0;
    end else begin
        if( pxl_cen && px[2:0] == px_last && hact ) begin
            cur     <= nxt;
            cur_pal <= nxt_pal;
        end
        case( st )
            0: if( pxl_cen && px[2:0] == px_first && hact ) begin
                vram_addr <= vaddr_nxt;
                st <= 1;
            end
            1: st <= 2;                         // VRAM read latency
            2: begin
                code <= vram_q;
                st   <= 3;
            end
            3: begin
                rom_addr <= raddr;
                rom_cs   <= 1;
                st       <= 4;
            end
            4: if( rom_ok ) begin
                nxt     <= rom_data;
                nxt_pal <= code[15:16-PALW];
                rom_cs  <= 0;
                st      <= 0;
            end
            default: st <= 0;
        endcase
    end
end

endmodule

// ---------------------------------------------------------------------------
// Sprites. Object RAM (512 entries of four words) is copied into a frame
// buffer when vertical blanking starts. During each line the copy is scanned
// from entry 511 down to 0 and the sprites covering the next line are drawn
// into a line buffer, later entries overwriting earlier ones so entry 0 wins.
// The display side reads the other line buffer and clears it behind the read.
//
// Entry words: 0 code[10:0]; 1 attr = colour[5:0], flipx bit 8, flipy bit 9,
// prio[11:10]; 2 x<<7; 3 y<<7. Screen x = x-32 (a further -14 when flipped in
// x), y = y-16; y == 0x100 hides the sprite and prio 0 skips it.
//
// Time per line is 446 pixels x 6 clocks = 2676: the scan reads only the y
// word, one entry a clock (512), and each sprite on the line costs about 30
// more, so some 70 sprites per line fit; beyond that `ovf` latches and the
// rest are dropped.
module jtwardner_obj(
    input             rst, clk, pxl_cen,
    input             LVBL,
    input      [ 8:0] hdump, vrender,
    output reg [10:0] ram_addr,
    input      [15:0] ram_q,
    output reg [15:0] rom_addr,
    input      [31:0] rom_data,
    output reg        rom_cs,
    input             rom_ok,
    output reg [12:0] pxl,
    output reg        ovf
);

// ---- frame copy of the object RAM, 2048 clocks from the fall of LVBL
reg  [15:0] frame[0:2047];
reg  [15:0] frame_q;
reg  [10:0] cp, cp_addr;
reg         copying, LVBL_l, we1, we2;
reg  [10:0] frd_addr;

always @(posedge clk) begin
    ram_addr <= cp;
    cp_addr  <= ram_addr;
    we1      <= copying;
    we2      <= we1;
    if( we2 ) frame[cp_addr] <= ram_q;      // ram_q is one clock behind ram_addr
    frame_q  <= frame[frd_addr];
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        copying <= 0; cp <= 0; LVBL_l <= 1;
    end else begin
        LVBL_l <= LVBL;
        if( LVBL_l && !LVBL ) begin
            copying <= 1;
            cp      <= 0;
        end else if( copying ) begin
            cp <= cp + 11'd1;
            if( cp == 11'd2047 ) copying <= 0;
        end
    end
end

// ---- line buffer: two lines of 512 x 13 bits. `line` is the one shown;
//      swapped at the last count of the line, when the renderer starts too.
//      TODO: map on to jtframe_dual_ram for synthesis (two write ports here)
reg  [12:0] lbuf[0:1023];
reg  [12:0] lbuf_q;
reg         line, rd_stb, rd_clr;
reg  [ 8:0] wr_x;
reg  [12:0] wr_d;
reg         wr_en;
wire        start = pxl_cen && hdump == 9'd445;   // next count is pixel 0

always @(posedge clk) begin
    lbuf_q <= lbuf[{line, hdump}];
    if( rd_clr ) lbuf[{ line, hdump}] <= 13'd0;
    if( wr_en  ) lbuf[{~line, wr_x }] <= wr_d;
end

// read one clock after the enable (hdump has settled), clear one later, and
// hold the pixel for the mixer
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        line <= 0; rd_stb <= 0; rd_clr <= 0; pxl <= 0;
    end else begin
        if( start ) line <= ~line;
        rd_stb <= pxl_cen;
        rd_clr <= rd_stb;
        if( rd_clr ) pxl <= lbuf_q;
    end
end

// ---- renderer. Scans entry 511 down to 0 reading the y word, one entry a
//      clock through a small pipeline; on a hit it fetches attr, code and x,
//      two ROM words, and writes the 16 pixels one a clock.
reg  [ 3:0] st;
reg  [ 9:0] entry;            // bit 9 set once entry 0 has been issued
reg  [ 8:0] hit_e, e1, e2;
reg         v1, v2;           // a y word is in flight
reg  [15:0] w_code, w_attr, w_x, w_y;
reg  [ 8:0] ly;               // line being rendered
reg  [31:0] half0, half1;
reg  [ 4:0] pcnt;
reg         busy;
reg [511:0] touched;          // pixels of the write line any sprite has hit

wire [ 8:0] sy    = w_y[15:7];
wire [ 8:0] sx    = w_x[15:7];
wire        flipx = w_attr[8], flipy = w_attr[9];
wire [ 1:0] prio  = w_attr[11:10];
wire [ 8:0] ydiff = ly - (sy - 9'd16);
// hit test on the y word as it arrives
wire [ 8:0] q_sy   = frame_q[15:7];
wire [ 8:0] q_diff = ly - (q_sy - 9'd16);
wire        yhit   = q_sy != 9'h100 && q_diff < 9'd16;
wire [ 8:0] x0    = sx - 9'd32 - (flipx ? 9'd14 : 9'd0);
wire [ 3:0] srow  = flipy ? ~ydiff[3:0] : ydiff[3:0];
wire [ 3:0] pix_i = flipx ? ~pcnt[3:0] : pcnt[3:0];
wire [31:0] half  = pix_i[3] ? half1 : half0;
wire [ 2:0] psh   = ~pix_i[2:0];
wire [ 7:0] hf3 = half[31:24], hf2 = half[23:16], hf1 = half[15:8], hf0 = half[7:0];
// same MSB-first plane order as the tilemaps, see jtwardner_tile
wire [ 3:0] pen   = { hf0[psh], hf1[psh], hf2[psh], hf3[psh] };
wire [ 8:0] px    = x0 + {5'd0, pcnt[3:0]};

localparam SCAN=0, DRAIN=1, FETCH0=2, FETCH1=3, FETCH2=4, FETCH3=5,
           FETCH4=6, ROM0=7, ROM1=8, DRAW=9, NEXT=10;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st <= SCAN; entry <= 0; busy <= 0; rom_cs <= 0; wr_en <= 0; ovf <= 0;
        frd_addr <= 0; rom_addr <= 0; wr_x <= 0; wr_d <= 0; pcnt <= 0;
        w_code <= 0; w_attr <= 0; w_x <= 0; w_y <= 0; ly <= 0;
        half0 <= 0; half1 <= 0; touched <= 0; hit_e <= 0; e1 <= 0; e2 <= 0;
        v1 <= 0; v2 <= 0;
    end else begin
        wr_en <= 0;
        if( start ) begin
            ly      <= vrender;
            entry   <= 10'd511;
            v1      <= 0; v2 <= 0;
            touched <= 0;
            // only visible lines need sprites; the frame copy takes the
            // beginning of line 240 and nothing reads the copy then
            busy    <= vrender < 9'd240;
            st      <= SCAN;
            rom_cs  <= 0;
            if( busy ) ovf <= 1;                // previous line not finished
        end else if( busy ) begin
            // data pipeline, two clocks behind the address
            v2 <= v1; e2 <= e1;
            case( st )
                SCAN: begin
                    frd_addr <= { entry[8:0], 2'd3 };
                    v1 <= 1;
                    e1 <= entry[8:0];
                    entry <= entry - 10'd1;
                    if( entry == 10'd0 ) st <= DRAIN;
                    if( v2 && yhit ) begin
                        w_y   <= frame_q;
                        hit_e <= e2;
                        v1    <= 0; v2 <= 0;
                        st    <= FETCH0;
                    end
                end
                DRAIN: begin                    // last two words still in flight
                    v1 <= 0;
                    if( v2 ) begin
                        if( yhit ) begin
                            w_y   <= frame_q;
                            hit_e <= e2;
                            v2    <= 0;
                            st    <= FETCH0;
                        end else if( !v1 ) busy <= 0;
                    end else if( !v1 ) busy <= 0;
                end
                // attr, code and x of the hit entry
                FETCH0: begin frd_addr <= {hit_e, 2'd1}; st <= FETCH1; end
                FETCH1: begin frd_addr <= {hit_e, 2'd0}; st <= FETCH2; end
                FETCH2: begin frd_addr <= {hit_e, 2'd2}; w_attr <= frame_q; st <= FETCH3; end
                FETCH3: begin
                    w_code <= frame_q;
                    // priority 0 entries are skipped
                    st     <= prio == 2'd0 ? NEXT : FETCH4;
                end
                FETCH4: begin
                    w_x      <= frame_q;
                    rom_addr <= { w_code[10:0], srow, 1'b0 };
                    rom_cs   <= 1;
                    st       <= ROM0;
                end
                ROM0: if( rom_ok ) begin
                    half0    <= rom_data;
                    rom_addr <= { w_code[10:0], srow, 1'b1 };
                    st       <= ROM1;
                end
                ROM1: if( rom_ok ) begin
                    half1  <= rom_data;
                    rom_cs <= 0;
                    pcnt   <= 0;
                    st     <= DRAW;
                end
                DRAW: begin
                    // pen 0 leaves the buffer alone. MAME marks every
                    // touched pixel priority 31 whether it drew or not, so a
                    // pixel hit twice is never hidden: that is the multi bit
                    if( pen != 4'd0 && px < 9'd320 ) begin
                        wr_x        <= px;
                        wr_d        <= { touched[px], prio, w_attr[5:0], pen };
                        wr_en       <= 1;
                        touched[px] <= 1;
                    end
                    pcnt <= pcnt + 5'd1;
                    if( pcnt == 5'd15 ) st <= NEXT;
                end
                NEXT: begin
                    // resume the scan below the sprite just drawn
                    if( hit_e == 9'd0 ) busy <= 0;
                    entry <= {1'b0, hit_e} - 10'd1;
                    st    <= SCAN;
                end
                default: st <= SCAN;
            endcase
        end
    end
end

endmodule
