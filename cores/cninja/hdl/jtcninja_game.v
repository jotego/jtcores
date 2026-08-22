/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Andrea Bogazzi
    Version: 0.1 (scaffold)
    Date: 2026

    SCAFFOLD -- Data East DECO 16-bit (cninja.cpp), Caveman Ninja / Joe & Mac.
    This is a structural skeleton: submodules are stubs. See doc/STATUS.md.
*/

module jtcninja_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// ---------------------------------------------------------------------------
// Main CPU bus
// (main_dout, dsn, main_addr, the audio channels and red/green/blue are
//  generated game ports - declared via mem_ports.inc / common_ports.inc -
//  so they are driven here, not redeclared)
// ---------------------------------------------------------------------------
wire        UDSWn, LDSWn, main_rnw;

// Tilegen (deco16ic x2) chip-select / register interface
wire        pf0_cs, pf1_cs;     // tilegen[0] / tilegen[1] register banks
wire [15:0] pf0_dout, pf1_dout;

// Sprites (decospr)
wire        objram_cs, obj_copy;
// Sprite gfx ROM: the engine drives one logical 32-bit bus (obj_*), fanned out
// to the two parallel 1MB banks obj1 (BA0, planes 0,1) + obj2 (BA1, planes 2,3).
wire [20:2] obj_addr;
wire        obj_cs, obj_ok;
wire [31:0] obj_data;

// DECO 16-bit data strobes (no SDRAM rw bus references this any more, so dsn is
// a plain local wire now that work RAM lives in BRAM).
wire [ 1:0] dsn;

// Palette
wire        pal_cs;

// Protection (DECO 104) -- the critical-path block
wire        prot_cs;
wire [15:0] prot_dout;

// Sound. cninja routes the soundlatch through the DECO 104 (prot_*); darkseal
// writes 0x180008 directly (main.v snd_wr/snd_dout). Muxed on game_id below.
wire [ 7:0] snd_latch, prot_snd_latch, ds_snd_latch;
wire        snd_irq,   prot_snd_irq;
wire        snd_wr;
wire [ 7:0] snd_dout;
reg  [ 7:0] ds_snd_latch_r;
reg         snd_wr_l;
wire        dseal = game_id==4'd2;
wire        cbust = game_id==4'd1;
wire        vapor = game_id==4'd3;     // Vapor Trail / Kuhga (2x deco16ic, no prot)
// cbuster's soundlatch is a plain generic_latch written from the main bus
// (0x0bc002), exactly like darkseal's 0x180008 - so both use the direct
// snd_wr/snd_dout path (main.v asserts snd_wr per game_id).
wire        dirsnd = dseal | cbust | vapor;  // vapor: generic latch @0x100007
always @(posedge clk) begin
    snd_wr_l <= snd_wr;
    if( snd_wr ) ds_snd_latch_r <= snd_dout;
end
assign ds_snd_latch = ds_snd_latch_r;
assign snd_latch    = dirsnd ? ds_snd_latch : prot_snd_latch;
assign snd_irq      = dirsnd ? (snd_wr & ~snd_wr_l) : prot_snd_irq;

// Video vertical position (deco_irq raster/vblank lives in main)
wire [ 8:0] vdump;

// Video timing / mix
wire        flip;
wire        cb_pri;    // cbuster TC-4 layer priority (main -> video colmix)

assign dsn        = { UDSWn, LDSWn };
assign objcpu_addr = main_addr[10:1];
assign objcpu_we   = {2{objram_cs & ~main_rnw}} & ~dsn;
assign dip_flip   = flip;
assign debug_view = 8'd0;
assign st_dout    = 8'd0;

// Sprite gfx: ONE interleaved 2MB bank (BA0), read as a single dw32 (8px/read).
// The download remap (below) packs the RGN_FRAC(1,2) plane-pairs into 32-bit
// {pl3,pl2,pl1,pl0} words, so no 2-bank parallel fetch / recombine.
assign objrom_addr = obj_addr;       // engine 32-bit word index -> dw32 port [20:2]
assign objrom_cs   = obj_cs;
assign obj_data    = objrom_data;
assign obj_ok      = objrom_ok;


// ROM download remap (BA3 = char/tiles1/tiles2). NOTE: post_addr/prog_addr are
// 16-bit-WORD addresses (jtframe_dwnld: prog_addr=(part_addr-BA_START)>>1; the
// byte lane comes from prog_mask, so a remap can only move whole words). BA3 word
// layout:  char 0x00000-0x10000 | tiles1 0x10000-0x50000 | tiles2 0x50000-0xD0000
// The deco16ic 4bpp tiles are RGN_FRAC(1,2): planes 0,1 in the first ROM half and
// planes 2,3 in the second. Rotating each region's word offset left by 1 (moving
// the half-select MSB to the LSB) interleaves the halves so one 32-bit read packs
// {plane1,plane0} and {plane3,plane2}. tiles2 also needs the MAME ROM_CONTINUE
// de-interleave (mame2mra emits mag-00|mag-01 naive; the real region swaps the
// middle 256kB blocks = word bits 17<->18), folded into the rotate. Verified
// end-to-end against the MAME gfxdecode (0 px mismatch).
//
// Sprites are NOT remapped here: they load as ONE contiguous 2MB region at the
// blob start, and the jtframe_dwnld boundary at JTFRAME_BA1_START splits the
// RGN_FRAC(1,2) plane pairs into BA0 (planes 0,1) + BA1 (planes 2,3) for free.
// The sprite engine then reads both banks in parallel (obj1/obj2 combine below).
// Per-game gfx region boundaries (BA3 word offsets), carried in the MRA header
// and latched at download (see the header decode below). The header stores them
// in 64kB-word units (value<<16 = word offset). This replaces the hardcoded
// cninja constants so any game's gfx layout works without HDL edits: mame2mra
// computes the ends from the actual ROM region sizes. It fixes the overlap class
// of bug (a region smaller than its slot leaves blob padding that the RGN_FRAC
// rotate would otherwise fold back onto - and overwrite - the real data, because
// the rotate ignores prog_addr bits above the region size).
reg  [ 5:0] gfx_t1  = 6'h01;   // char end / tiles1 base  (cninja default)
reg  [ 5:0] gfx_t2  = 6'h05;   // tiles1 end / tiles2 base
reg  [ 5:0] gfx_end = 6'h0d;   // tiles2 end
reg         gfx_romcont = 1'b1;// tiles2 has ROM_CONTINUE (word bit 17<->18 swap)
wire [21:0] gT1  = { gfx_t1,  16'd0 };
wire [21:0] gT2  = { gfx_t2,  16'd0 };
wire [21:0] gEND = { gfx_end, 16'd0 };
wire [19:0] t1w = prog_addr[19:0] - gT1[19:0];   // tiles1-relative word
wire [19:0] t2w = prog_addr[19:0] - gT2[19:0];   // tiles2-relative word
// tiles2 COPY 2 lives in BA2 at (GFX3_BA2_START-BA2_START)>>1 = 0xC8000 words
// (after main+oki). scr3 reads it parallel to scr2's copy1 in BA1.
localparam [21:0] GT2B = 22'h0C8000;
wire [19:0] t2bw = prog_addr[19:0] - GT2B[19:0]; // tiles2-copy2-relative word
// BA0 holds the sound program above the 2MB sprite slot: (SND_START-0)>>1.
// It must download raw, so the sprite plane-pair rotate below stops here.
localparam [21:0] SNDW = 22'h100000;
always @* begin
    post_data = prog_data;
    post_addr = prog_addr;                                   // identity (proms)
    // Sprites (BA0): interleave the RGN_FRAC(1,2) plane-pairs into 32-bit chunky.
    // Rotate the plane-pair-select word bit (the FRAC half: planes 0,1 in the low
    // half of the region, 2,3 in the high half) down to the LSB so {pl1,pl0} and
    // {pl3,pl2} land at the two halves of one dw32 word. cninja sprites = 2MB -> bit
    // 19; darkseal 1MB -> bit 18; cbuster is already chunky -> identity.
    // cninja sprites are now packed chunky in the MRA (frac/parts, maps 0021/2100)
    // so they load identity; cbuster sprites are already chunky. Only darkseal/
    // vaportra still pack the RGN_FRAC(1,2) 1MB plane-pair here (TODO: MRA parts).
    // Those sprites are 1MB in the 2MB BA0 slot. Keep prog_addr[20:19]
    // (was 3'b0) so the 1MB of 0xFF padding stays in the high half instead of
    // folding the rotate back onto the real sprite data and erasing it (white
    // squares). bit 18 = the RGN_FRAC(1,2) plane-pair split for the 1MB region.
    if( prog_ba==2'd0 && (dseal | vapor) && prog_addr < SNDW ) // vaportra sprites 1MB = same
        post_addr = { prog_addr[20:19], prog_addr[17:0], prog_addr[18] };
    // Dark Seal maincpu (BA2, first 512kB) is data-line scrambled: MAME's
    // driver_init swaps data bits D1<->D6 across the whole 68k ROM
    //   rom = (rom&0xbd) | ((rom&0x02)<<5) | ((rom&0x40)>>5)
    // Apply the same swap during download (game_id==2 only). The download is
    // byte-wide (prog_data[7:0]), so swap bits 6<->1 of each byte.
    if( dseal && prog_ba==2'd2 && prog_addr < 22'h40000 )
        post_data = { prog_data[7], prog_data[1], prog_data[5:2], prog_data[6], prog_data[0] };
    // Vapor Trail maincpu (BA2, 512kB) decrypt: MAME driver_init swaps data bit7<->bit0
    //   rom = bitswap<8>(rom, 0,6,5,4,3,2,1,7)  -> out = {in[0], in[6:1], in[7]}.
    // Whole 68k ROM (0..0x7ffff bytes = 0..0x40000 words). gfx are MRA-chunky (identity).
    if( vapor && prog_ba==2'd2 && prog_addr < 22'h40000 )
        post_data = { prog_data[0], prog_data[6:1], prog_data[7] };
    // Crude Buster maincpu is also data-line scrambled (MAME init_twocrude) but
    // with a DIFFERENT permutation per byte of each 68k word, so it cannot be
    // undone here: the download remap is byte-serial and the game side sees only
    // the 8-bit data + WORD address (no byte lane). cbuster is instead decrypted
    // on the READ path in jtcninja_main (where [15:8]=MSB / [7:0]=LSB are known).
    // cbuster's tiles are RGN_FRAC(1,1) byte-per-plane = ALREADY chunky
    // {p3,p2,p1,p0} with word-in-tile=half*16+row, so they load with IDENTITY
    // post_addr. The RGN_FRAC(1,2) plane-interleave rotate below is cninja/darkseal
    // ONLY - applying it to cbuster scrambles the tiles into flat (colored-square)
    // garbage. Gate it off for cbust.
    // cninja BA3 (char + tiles1) is now MRA chunky (frac/parts) -> identity.
    // darkseal/vaportra still pack RGN_FRAC(1,2) here in the download.
    if( prog_ba==2'd3 && (dseal | vapor) ) begin            // BA3 = char + tiles1
        if( prog_addr < gT1 )                                // char  (half @ word bit15)
            post_addr = { 6'd0, prog_addr[14:0], prog_addr[15] };
        else if( prog_addr < gT2 )                           // tiles1 512KB (half @ word bit17)
            post_addr = gT1 + { 4'd0, t1w[16:0], t1w[17] };
    end
    // BA1 = tiles2 (moved off BA3 so scr2+scr3 fetch in parallel with BA3 char+scr1).
    // Same RGN_FRAC + ROM_CONTINUE rotate, now relative to BA1 (tiles2 at offset 0):
    // gfx_romcont = +ROM_CONTINUE word bit17<->18 swap (1MB cninja) else plain rotate.
    // cninja tiles2 copy1 is now MRA chunky (frac/parts) -> identity. darkseal
    // still packs RGN_FRAC(1,2) here (single ROM, no ROM_CONTINUE).
    // vaportra tiles2 is 1MB RGN_FRAC(1,2) (vtmaa02|vtmaa01) -> frac bit is 18;
    // move it to the LSB (no padding bit to keep, the 1MB fills the slot).
    if( prog_ba==2'd1 && vapor )
        post_addr = { 3'd0, prog_addr[17:0], prog_addr[18] };
    else if( prog_ba==2'd1 && dseal )
        post_addr = gfx_romcont ? { 3'd0, prog_addr[18], prog_addr[16:0], prog_addr[17] }
                                : { 3'd0, prog_addr[18], prog_addr[16:0], prog_addr[17] }; // keep bit18: darkseal 512KB tiles2 in 1MB slot, else padding folds onto data
    // BA2 = main + oki + tiles2 COPY 2. main/oki (prog_addr < GT2B) keep identity
    // (+ the dseal data-scramble on post_data above); the tiles2 copy2 region
    // (>= GT2B) gets the SAME rotate as the BA1 copy, relative to the BA2 base.
    if( prog_ba==2'd2 && vapor && prog_addr >= GT2B )        // vaportra tiles2 copy2 (1MB, bit18)
        post_addr = GT2B + { 3'd0, t2bw[17:0], t2bw[18] };
    else if( prog_ba==2'd2 && dseal && prog_addr >= GT2B )
        post_addr = GT2B + ( gfx_romcont ? { 3'd0, t2bw[18], t2bw[16:0], t2bw[17] }
                                         : { 3'd0, t2bw[18], t2bw[16:0], t2bw[17] } ); // keep bit18 (see BA1)
    // ROW-MAJOR (cninja only, TEST): the MRA-chunky tiles are half-major (L 8px
    // col x16 rows, then R). Move the L/R half-select word bit (prog_addr[5]) down
    // to the dw32-word LSB (bit 1) so a row's two halves are ADJACENT dw32 words ->
    // the 2nd read is a 64-bit cache hit. deco16 roma16 swaps rhalf<->rsubrw to match.
    if( ~dseal & ~cbust & ~vapor ) begin                            // cninja only
        if( prog_ba==2'd1 ||                                        // tiles2 copy1 (BA1)
            (prog_ba==2'd2 && prog_addr >= GT2B) ||                 // tiles2 copy2 (BA2)
            (prog_ba==2'd3 && prog_addr >= gT1 && prog_addr < gT2) )// tiles1 (BA3)
            post_addr = { prog_addr[20:6], prog_addr[4:1], prog_addr[5], prog_addr[0] };
    end
    // vaportra: gfx are MRA-chunky AND half-major (no row-major rotate) -> identity
    // download for all banks (video.v sets rowmajor=0 for vapor to match).
end

// ---------------------------------------------------------------------------
// Caveman Ninja Hardware family selector (multi-game, header-driven).
// MRA header byte 0 = game_id, latched during the header phase of the download
// (superman/kiwi pattern). 0=cninja, 1=cbuster/twocrude, 2=darkseal/gatedoom.
// The address decoder / I/O / clock cens mux on game_id; game_id=0 == cninja.
// ---------------------------------------------------------------------------
// Header is delivered BYTE-addressed during the header phase: game_sdram.v
// feeds the game prog_addr=ioctl_addr (byte index) and prog_data=ioctl_dout
// (the byte in [7:0]; [15:8] is zero-extended). So each header byte lands at
// its own prog_addr[3:0] and must be read from prog_data[7:0] - NOT packed two
// bytes per 16-bit word. Byte layout (matches mame2mra [header] data order):
//   byte 0 = game_id     byte 1 = gfx_t1 (char end / tiles1 base)
//   byte 2 = gfx_t2      byte 3 = gfx_end (tiles2 end)
//   byte 4 bit0 = tiles2 ROM_CONTINUE      (all values in 64kB-word units)
// game_id is normally latched from the MRA header during the ROM download.
// Scene replay (NOMAIN) primes the SDRAM from sdram_bank*.bin and skips that
// download, so the header never arrives - force game_id via JTFRAME_SIM_GAMEID
// (e.g. -d JTFRAME_SIM_GAMEID=2 for darkseal) so the video uses the right paths.
`ifdef JTFRAME_SIM_GAMEID
reg [3:0] game_id = `JTFRAME_SIM_GAMEID;
`else
reg [3:0] game_id = 4'd0;
`endif
always @(posedge clk) begin
    if( prog_we && header ) case( prog_addr[3:0] )
        4'd0: game_id     <= prog_data[3:0];
        4'd1: gfx_t1      <= prog_data[5:0];
        4'd2: gfx_t2      <= prog_data[5:0];
        4'd3: gfx_end     <= prog_data[5:0];
        4'd4: gfx_romcont <= prog_data[0];
        default:;
    endcase
end

/* verilator tracing_off */
jtcninja_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .LVBL       ( LVBL      ),
    .LHBL       ( LHBL      ),
    // CPU bus
    .cpu_addr   ( main_addr ),
    .cpu_dout   ( main_dout ),
    .UDSWn      ( UDSWn     ),
    .LDSWn      ( LDSWn     ),
    .RnW        ( main_rnw  ),
    // Program ROM (work RAM is internal BRAM, no SDRAM bus)
    .rom_cs     ( main_cs   ),
    .rom_data   ( main_data ),
    .rom_ok     ( main_ok   ),
    // Video subsystem chip-selects
    .pf0_cs     ( pf0_cs    ),
    .pf1_cs     ( pf1_cs    ),
    .pf0_dout   ( pf0_dout  ),
    .pf1_dout   ( pf1_dout  ),
    .objram_cs  ( objram_cs ),
    .obj_copy   ( obj_copy  ),
    .obj_dout   ( obj_dout  ),
    .pal_cs     ( pal_cs    ),
    .pal_dout   ( palrw_dout ),
    // Protection (DECO 104) - reads inputs/dips, carries the sound latch
    .prot_cs    ( prot_cs   ),
    .prot_dout  ( prot_dout ),
    // Caveman Ninja Hardware family selector + Dark Seal direct I/O
    .game_id    ( game_id   ),
    .prot_pri   ( cb_pri    ),
    .snd_wr     ( snd_wr    ),
    .snd_dout   ( snd_dout  ),
    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .cab_1p     ( cab_1p    ),
    .coin       ( coin      ),
    .dipsw      ( dipsw[15:0] ),
    // misc
    .vdump      ( vdump     ),
    .dip_pause  ( dip_pause )
);

/* verilator tracing_off */
jtcninja_deco104 u_prot(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .LVBL       ( LVBL      ),
    .cs         ( prot_cs   ),
    .addr       ( main_addr[13:1] ),   // offset within the 0x4000 prot region
    .din        ( main_dout ),
    .dout       ( prot_dout ),
    .rnw        ( main_rnw  ),
    .dsn        ( dsn       ),
    // Cabinet inputs (muxed/scrambled by the chip)
    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .cab_1p     ( cab_1p    ),
    .coin       ( coin      ),
    .service    ( service   ),
    .dip_test   ( dip_test  ),
    .dipsw      ( dipsw[15:0] ),
    // Sound (cninja path; muxed against the darkseal direct latch above)
    .snd_latch  ( prot_snd_latch ),
    .snd_irq    ( prot_snd_irq   )
);

/* verilator tracing_on */
jtcninja_snd u_snd(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_snd    ( cen_snd   ),
    .cen_opn    ( cen_opn   ),
    .cen_opm    ( cen_opm   ),
    .cen_oki1   ( cen_oki1  ),
    .cen_oki2   ( cen_oki2  ),
    .dseal      ( dseal     ),
    // From main CPU (via DECO 104 latch)
    .latch      ( snd_latch ),
    .snd_irq    ( snd_irq   ),
    // Program ROM: 64kB HuC6280 program in BA0, above the sprite slot
    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),
    // OKI #1
    .oki1_addr  ( oki1_addr ),
    .oki1_cs    ( oki1_cs   ),
    .oki1_data  ( oki1_data ),
    .oki1_ok    ( oki1_ok   ),
    // OKI #2
    .oki2_addr  ( oki2_addr ),
    .oki2_cs    ( oki2_cs   ),
    .oki2_data  ( oki2_data ),
    .oki2_ok    ( oki2_ok   ),
    // Mixed channels (YM2151 is stereo: opm_l/opm_r)
    .opn        ( opn       ),
    .psg        ( psg       ),
    .opm_l      ( opm_l     ),
    .opm_r      ( opm_r     ),
    .pcm1       ( pcm1      ),
    .pcm2       ( pcm2      )
);

/* verilator tracing_off */
jtcninja_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),
    .gfx_en     ( gfx_en    ),
    .flip       ( flip      ),
    .game_id    ( game_id   ),
    .cbpri      ( cb_pri    ),
    // CPU interface (widened to [19:1] so video can decode darkseal's exploded
    // tilegen/palette regions; cninja only needs [15:1])
    .cpu_addr   ( main_addr[19:1] ),
    .cpu_dout   ( main_dout ),
    .cpu_dsn    ( dsn       ),
    .cpu_rnw    ( main_rnw  ),
    .pf0_cs     ( pf0_cs    ),
    .pf1_cs     ( pf1_cs    ),
    .pf0_dout   ( pf0_dout  ),
    .pf1_dout   ( pf1_dout  ),
    .obj_copy   ( obj_copy  ),
    .oram_addr  ( oram_addr ),
    .oram_dout  ( oram_dout ),
    .dma_addr   ( dma_addr  ),
    .dma_we     ( dma_we    ),
    .pal_cs     ( pal_cs     ),
    .palrw_addr ( palrw_addr ),
    .palrw_we   ( palrw_we   ),
    .pal_addr   ( pal_addr   ),
    .pal_dout   ( pal_dout   ),
    // Tile ROMs (BA2)
    .char_cs    ( char_cs   ),
    .char_addr  ( char_addr ),
    .char_data  ( char_data ),
    .char_ok    ( char_ok   ),
    .scr1_cs    ( scr1_cs   ),
    .scr1_addr  ( scr1_addr ),
    .scr1_data  ( scr1_data ),
    .scr1_ok    ( scr1_ok   ),
    .scr2_cs    ( scr2_cs   ),
    .scr2_addr  ( scr2_addr ),
    .scr2_data  ( scr2_data ),
    .scr2_ok    ( scr2_ok   ),
    .scr3_cs    ( scr3_cs   ),
    .scr3_addr  ( scr3_addr ),
    .scr3_data  ( scr3_data ),
    .scr3_ok    ( scr3_ok   ),
    // Sprite ROM (BA3)
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),
    .obj_ok     ( obj_ok    ),
    // Vertical position
    .vdump      ( vdump     ),
    // Video output
    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

endmodule
