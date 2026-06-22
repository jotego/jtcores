//============================================================================
//
//  jtddribble_5885_7121_gfx.v — adapted from cores/contra/hdl/jtcontra_gfx.v
//
//  This file is a copy of Jotego's Konami 007121 HDL implementation,
//  renamed for use inside the Double Dribble core via the thin schematic-
//  facing wrapper `jtddribble_5885.v`.
//
//  The 007121 is documented (MAME `konami/k007121.cpp`) as "an evolution
//  of the 005885, with more features". The 005885 is therefore a SUBSET
//  of the 007121 behaviour.
//
//  Phase 2 of the 005885 build plan will add a `MODE_5885 = 0` parameter
//  with `generate` blocks that gate the 007121-only features off when
//  `MODE_5885 = 1`. Until that parameter is added, this file is byte-for-
//  byte identical to its parent (modulo the module/instance renames) and
//  behaves exactly like the 007121.
//
//  See cores/ddribble/doc/005885_implementation.md for the full plan
//  (current strategy: parameterize this file + keep `jtddribble_5885.v`
//  as the schematic-facing wrapper).
//
//  Eventual destination: when the parameterized version is stable, the
//  intent is to promote this file (and its companions _tilemap, _obj)
//  to a shared `modules/jtkonami/` location so contra + labrun + comsc +
//  flane + castle + mx5k + ddribble all consume the same source. That
//  promotion is a SEPARATE PR — not included in the ddribble PR.
//
//============================================================================

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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 02-05-2020 */

// Main features of Konami's 007121 hardware
// Some elements have been factored out one level up (H/S timing...)

//  IRQ triggers once per frame
// FIRQ triggers once per ?
//  NMI triggers once per 16/32 scanlines

module jtddribble_5885_7121_gfx(
    input                rst,
    input                clk,
    input                clk24,
    input                pxl2_cen,
    input                pxl_cen,

    // output if VTIMER = 1, input otherwise
    inout                LHBL,
    inout                LVBL,
    inout                HS,
    inout                VS,
    inout   [8:0]        hdump,
    inout   [8:0]        vdump,
    inout   [8:0]        vrender,
    inout   [8:0]        vrender1,

    output               flip,
    // PROMs
    input      [ 8:0]    prog_addr,
    input      [ 3:0]    prog_data,
    input                prom_we,
    // CPU      interface
    input                cs,
    input                cpu_rnw,
    input                cpu_cen,
    input      [13:0]    addr,
    input      [ 7:0]    cpu_dout,
    output reg [ 7:0]    dout,
    output reg           cpu_irqn,
    output reg           cpu_nmin,
    output reg           cpu_firqn,
    // External palette 007327
    output               col_cs,
    // SDRAM interface
    output reg           rom_obj_sel,   // pin H2 of actual chip
    output reg [17:0]    rom_addr,
    input      [15:0]    rom_data,
    input                rom_ok,
    output reg           rom_cs,
    // colour output
    output reg [ 6:0]    pxl_out,
    output reg [ 3:0]    pxl_pal,
    // test
    input      [ 7:0]    debug_bus,
    output reg [ 7:0]    st_dout,
    input      [ 1:0]    gfx_en
);

parameter   H0 = 9'h75; // initial value of hdump after H blanking
parameter   BYPASS_VPROM=0, // bypass tile/char colour PROM (pins VCB/VCF/VCD)
            BYPASS_OPROM=0, // bypass object colour PROM (pins OCF/OCD)
            VTIMER=1;
// SCHEMATIC (ddribble GX690, page 0 gfx-ROM section): on the real board each
// 005885's tile and sprite patterns live in physically SEPARATE ROM banks,
// selected by chip-enable / clock phase — NOT a shared linear address:
//   * E16 (chip 1): one ROM pair E12/E13 (256 KB). a16=NCLKE time-splits it:
//       tile half = lower 128 KB (word 0x00000), sprite half = upper 128 KB
//       (word 0x10000). So sprite fetch must land at word offset 0x10000.
//   * H16 (chip 2): two ROM pairs (512 KB). I12/I13 = tile bank (CE=NCLKE),
//       I8/I11 = sprite bank (CE=OBL). MAME blob mirrors this: tiles word
//       0x00000, sprites word 0x20000. So sprite fetch must land at 0x20000.
// Our single-blob-per-chip model reproduces this by FORCING the sprite (obj)
// fetch into the sprite half: rom_addr = OBJSTART | (rom_obj_addr & OBJMASK).
// OBJMASK keeps only the sprite-local address bits (chip's sprite ROM size),
// OBJSTART is the word offset of the sprite region. Tile fetches are left
// untouched (tile path already renders). Defaults below = no-op (007121
// behaviour) so non-ddribble users are unaffected.
parameter [17:0] OBJSTART = 18'h0_0000;     // word offset of sprite region
parameter [17:0] OBJMASK  = 18'h3_FFFF;     // sprite-local address mask

// MODE_5885 — 0 = full Konami 007121 (default, backwards-compatible).
//             1 = Konami 005885 subset (used by jtddribble_5885.v wrapper).
// The parameter is DECLARED here in step 2a of the 005885 build plan but
// has NO `generate` blocks consuming it yet — body behaviour is unchanged
// from the original jtcontra_gfx until later phases gate individual features.
// See cores/ddribble/doc/005885_implementation.md for the list of areas
// that will be gated when MODE_5885=1.
parameter   MODE_5885 = 0;

// Simulation files
parameter   CFGFILE="gfx_cfg.hex",
            SIMATTR="gfx_attr.bin",
            SIMCODE="gfx_code.bin",
            SIMOBJ ="gfx_obj.bin";

localparam  RCNT=8, ZURECNT=32;

reg         last_LVBL, last_irqn;
wire        gfx_we;
wire        done, scr_we;
wire        vram_cs, cfg_cs;

wire        line;
wire [9:0]  line_addr;
wire [8:0]  chr_pxl, scr_pxl, line_din;
wire [1:0]  prio_en;

////////// Memory Mapped Registers
reg  [7:0]  mmr[0:RCNT-1];
reg  [7:0]  zure[0:ZURECNT-1];  // zure RAM, row/col scroll
reg  [31:0] strip_map;          // Sets the row as a text (1) or scroll (0)
// ------------------------------------------------------------------
// MMR-derived wire declarations. Storage is `reg [7:0] mmr[]` above;
// these are read-only views into it. The actual register MEANING
// differs between 007121 and 005885 — see the generate block below.
// ------------------------------------------------------------------
wire [8:0]  hpos;
wire [7:0]  vpos;
wire        strip_en, strip_col, strip_txt;
wire        tile_msb;
wire        obj_page;
wire        layout;
wire        narrow_en;
wire [3:0]  extra_mask, extra_bits;
wire [1:0]  code9_sel, code10_sel, code11_sel, code12_sel;
wire        nmi_en, irq_en, firq_en;
wire        nmi_pace;
wire        pal_msb;
wire        hflip_en;
wire        vflip_en;
wire        scrwin_en;
wire [1:0]  pal_bank;
wire        extra_en   = 1; // there must be a bit in the MMR that turns off all the extra_bits above
                            // because Contra doesn't need them but seems to write to them
reg no_txt;
// wire [7:0] txt_mmr = mmr[debug_bus[5:3]];

// ------------------------------------------------------------------
// MMR register interpretation — branch on MODE_5885 parameter.
//
// 007121 (MODE_5885=0): 8 byte-wide CPU-visible registers (mmr[0..7]),
//   meanings per Jotego's jtcontra_gfx (today's behaviour, unchanged).
//
// 005885 (MODE_5885=1): 5 byte-wide registers (per MiSTer Iron Horse
//   `rtl/custom/k005885.sv` by Ace, also confirmed by konamiic.txt
//   in MAME sources). The base receives writes at the same mmr[]
//   storage, but the wire-decode reroutes them to the 005885's
//   actual semantics. See `cores/ddribble/doc/005885_implementation.md`.
//
// Putting both maps side-by-side here prevents the register-meaning
// collision described in the design doc: a given mmr[N][b] only
// feeds ONE downstream wire per elaborated branch.
// ------------------------------------------------------------------
generate
if (MODE_5885 == 1) begin : reg_map_5885
    // ---- 005885 register interpretation ----
    // reg 000: scroll_y
    assign vpos       = mmr[0];
    // reg 001 + reg 002[0]: scroll_x (9 bits)
    assign hpos       = { mmr[2][0], mmr[1] };
    // reg 002[3:1]: scroll mode (rowscroll / colscroll / solid scroll).
    // 005885 doesn't expose strip_* the way 007121 does — gate off for now.
    // A future phase will implement row/col-scroll properly using mmr[2][3:1].
    assign strip_en   = 1'b0;
    assign strip_col  = 1'b0;
    assign strip_txt  = 1'b0;
    // reg 003: tile_ctrl (per MiSTer ref).
    //   [1:0] = tile_upper (high tile-code bits, 2 bits only)
    //   [2]   = nmi pace selector (falling edge of vcnt4 vs vcnt5)
    //   [3]   = sprite-buffer select
    //   rest  = unknown
    assign tile_msb   = 1'b0;                    // 005885 tile_index is fixed 8-bit
    assign extra_mask = 4'd0;                    // 005885 has no per-bit mask layer
    assign extra_bits = { 2'b00, mmr[3][1:0] };  // 005885 tile_upper bits
    assign obj_page   = mmr[3][3];
    assign nmi_pace   = mmr[3][2];
    // reg 003: layout/narrow concepts don't exist on 005885
    assign layout     = 1'b0;
    assign narrow_en  = 1'b0;
    // reg 004: interrupt enables + flip screen
    assign nmi_en     = mmr[4][0];
    assign irq_en     = mmr[4][1];
    assign firq_en    = mmr[4][2];
    assign flip       = mmr[4][3];
    // 005885 has no separate code-attribute mux (R formula is fixed wiring
    // per MiSTer ref line 701). Force the four codeN_sel muxes to 2'b00.
    // TBD: verify this matches tilemap expectations once V1 sim renders.
    assign { code12_sel, code11_sel, code10_sel, code9_sel } = 8'h00;
    // Per-tile flip on 005885:
    // We're working from the assumption that the 005885 supports per-tile
    // X and Y flipping (basketball court rendering on the real PCB shows
    // right-half mirroring that's consistent with tile-level flip rather
    // than separate mirrored tile artwork). The 007121's master enable
    // register mmr[6] does not exist on the 005885, so we hard-wire the
    // enables ON. WHETHER attr_scan[4] / attr_scan[5] are actually where
    // the 005885 stores those bits in its attribute byte is NOT verified
    // yet — these are the slots the 007121 uses, kept here as the first
    // best guess. If flipping happens in the wrong direction (or doesn't
    // happen at all even with enables on), the next thing to try is
    // remapping which attr_scan bits the tilemap state machine reads.
    assign pal_msb    = 1'b0;
    assign hflip_en   = 1'b1;
    assign vflip_en   = 1'b1;
    assign scrwin_en  = 1'b0;
    assign pal_bank   = 2'b00;
    // 005885 priority semantics TBD — gate off, revisit when tiles render
    assign prio_en[0] = 1'b0;
    assign prio_en[1] = 1'b0;
end else begin : reg_map_7121
    // ---- 007121 register interpretation (unchanged from upstream jtcontra_gfx) ----
    assign hpos       = { mmr[1][0], mmr[0] };
    assign vpos       = mmr[2];
    assign strip_en   = mmr[1][1]; // strip scroll enable
    assign strip_col  = mmr[1][2]; // strip scroll applies to columns (1) or rows (0)
    assign strip_txt  = mmr[1][3]; // enables the text tilemap per strip
    assign tile_msb   = mmr[3][0];
    assign prio_en[0] = mmr[3][2]; // enables tile priority overall
    assign obj_page   = mmr[3][3]; // select from which page to draw sprites
    assign layout     = mmr[3][4]; // 5 columns on the left are text (wide layout)
    assign prio_en[1] = mmr[3][5]; // 0 gives priority to the scroll, even if scroll is zero
    assign narrow_en  = mmr[3][6]; // 1 for not displaying first and last columns
    assign extra_mask = mmr[4][7:4];
    assign extra_bits = mmr[4][3:0];
    assign { code12_sel, code11_sel, code10_sel, code9_sel } = mmr[5];
    assign pal_msb    = mmr[6][0];
    assign hflip_en   = mmr[6][1];
    assign vflip_en   = mmr[6][2];
    assign scrwin_en  = mmr[6][3];
    assign pal_bank   = mmr[6][5:4];
    assign nmi_en     = mmr[7][0];
    assign irq_en     = mmr[7][1];
    assign firq_en    = mmr[7][2];
    assign flip       = mmr[7][3];
    assign nmi_pace   = mmr[7][4]; // Selects NMI rate (16 vs 32 lines)
end
endgenerate
// Other configuration
reg  [8:0]  chr_render_start, scr_render_start;
reg         obj_page_l;

// Scan
wire [10:0] scan_addr;
wire [10:0] ram_addr = { addr[11], addr[9:0] };
wire        attr_we, code_we, obj_we;
wire [ 7:0] code_dout, attr_dout, obj_dout;
wire [ 7:0] code_scan, attr_scan, obj_scan;

reg  [ 7:0] vprom_addr;
wire [ 7:0] oprom_addr;
wire [ 3:0] vprom_data, oprom_data;
wire [ 7:0] obj_pxl;

wire [ 7:0] strip_pos;
wire [ 4:0] strip_addr;
reg         txt_en;

wire [9:0]  line_dump;

wire        rom_obj_cs, rom_scr_cs, zure_cs;
wire [17:0] rom_scr_addr, rom_obj_addr;

wire        LVBshort;

assign      line_dump = { ~line, hdump_disp };

// local SDRAM mux
reg  [ 1:0] data_sel;
reg         rom_scr_ok, rom_obj_ok;
reg  [15:0] rom_scr_data, rom_obj_data;
reg         ok_wait;
reg  [ 1:0] last_cs;

// Memory map
// 3XXX -> OBJ
// 2XXX -> Tiles
// 1XXX -> Color CS (external palette)
// 0XXX -> CFG registers

assign cfg_cs    = (addr < RCNT) && cs;
assign zure_cs   = (addr>='h20 && addr<'h60 && cs);
assign vram_cs   = addr[13] && cs;
assign col_cs    = addr[13:12]=='b01 && cs;
assign gfx_we    = cpu_cen & ~cpu_rnw & vram_cs;
assign obj_we    = gfx_we &  addr[12];
assign attr_we   = gfx_we & ~addr[12] & ~addr[10];
assign code_we   = gfx_we & ~addr[12] &  addr[10];
// hpos is driven inside the MODE_5885 generate block above.
assign strip_pos = zure[ strip_addr ];
assign LVBshort  = LVBL || vdump==15;

wire [7:0] zure_cpu = zure[addr[4:0]];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st_dout <= 0;
        no_txt  <= 0;
    end else begin
        st_dout <= mmr[debug_bus[2:0]];
        // no_txt <= txt_mmr[debug_bus[2:0]]^debug_bus[6];
        no_txt <= ~layout & ~strip_txt;
    end
end

// Data bus mux. It'd be nice to latch this:
always @(*) begin
    dout = !addr[13] ?
          { zure_cpu[7:1], addr[6] ? strip_map[addr[4:0]] : zure_cpu[0] } :
          (addr[12] ? obj_dout :            // objects
          (addr[10] ? code_dout : attr_dout)); // tiles
end

reg last_vdump8;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        obj_page_l  <= 0;
        last_vdump8 <= 0;
    end else begin
        last_vdump8 <= vdump[8];
        if( vdump[8] & ~last_vdump8 ) obj_page_l <= obj_page;
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_cs      <= 0;
        rom_addr    <= 18'd0;
        rom_obj_sel <= 0;
        data_sel    <= 2'b00;
        ok_wait     <= 0;
    end else begin
        last_cs <= { rom_obj_cs, rom_scr_cs };
        if( rom_obj_cs && !last_cs[1] ) rom_obj_ok<=0;
        if( rom_scr_cs && !last_cs[0] ) rom_scr_ok<=0;
        if( data_sel==2'b00 ) begin
            if( rom_scr_cs & gfx_en[0] ) begin
                rom_cs      <= 1;
                rom_addr    <= rom_scr_addr;
                rom_obj_sel <= 0;
                rom_scr_ok  <= 0;
                data_sel    <= 2'b01;
                ok_wait     <= 0;
            end else if( rom_obj_cs & gfx_en[1] ) begin
                rom_cs      <= 1;
                // SCHEMATIC: force the sprite fetch into the chip's sprite ROM
                // bank (separate CE bank on H16 / upper NCLKE half on E16).
                // OBJSTART = word offset of that bank; OBJMASK keeps only the
                // sprite-local bits. See OBJSTART/OBJMASK params above.
                rom_addr    <= OBJSTART | (rom_obj_addr & OBJMASK);
                rom_obj_sel <= 1;
                rom_obj_ok  <= 0;
                data_sel    <= 2'b10;
                ok_wait     <= 0;
            end
            else rom_cs <= 0;
        end else if( rom_ok & ok_wait) begin
            if( data_sel[0] ) begin
                rom_scr_data <= rom_data;
                rom_scr_ok   <= 1;
            end else if(!gfx_en[0]) begin
                rom_scr_data <= 16'd0;
                rom_scr_ok   <= 1;
            end
            if( data_sel[1] ) begin
                rom_obj_data <= rom_data;
                rom_obj_ok   <= 1;
            end else if( !gfx_en[1] ) begin
                rom_obj_data <= 16'd0;
                rom_obj_ok   <= 1;
            end
            data_sel <= 2'b00;
            rom_cs   <= 0;
        end else begin
            ok_wait <= 1;
        end
    end
end

`ifdef SIMULATION
initial $readmemh( CFGFILE, mmr );

// V1 bring-up instrumentation (jtddribble): log every CPU write into the
// chip's internal address space. `%m` prints the hierarchical path so we
// can tell chip 1 from chip 2 (e.g. game_test.u_game.u_game.u_k5885_1.u_chip).
//
// Tags:
//   CFG  = control-register write   (mmr[addr[2:0]])
//   ZURE = scroll/strip-map write   (addr 0x20..0x5F)
//   VRAM = tilemap/sprite RAM write (addr[13]=1, ~8 KB region inside chip)
//   COL  = color attribute write    (addr[13:12]=01)
// Reads not logged to keep log size manageable.
always @(posedge clk24) begin
    if (cpu_cen && !cpu_rnw && cs) begin
        if      (cfg_cs)  $display("[%0t] %m  CFG  reg=%0d data=%02X",          $time, addr[2:0],  cpu_dout);
        else if (zure_cs) $display("[%0t] %m  ZURE addr=%02X data=%02X",        $time, addr[6:0],  cpu_dout);
        else if (col_cs)  $display("[%0t] %m  COL  addr=%03X data=%02X",        $time, addr[11:0], cpu_dout);
        else if (vram_cs) $display("[%0t] %m  VRAM addr=%04X data=%02X",        $time, addr[12:0], cpu_dout);
    end
end
`endif

integer rst_cnt;

always @(posedge clk24) begin
    if( rst ) begin
        for( rst_cnt=0; rst_cnt<8; rst_cnt=rst_cnt+1 ) begin
            mmr[rst_cnt] <= 0;
        end
        for( rst_cnt=0; rst_cnt<32; rst_cnt=rst_cnt+1 ) begin
            zure[rst_cnt] <= 0;
            strip_map[rst_cnt] <= 0;
        end
    end else begin
        if(cpu_cen && !cpu_rnw) begin
            if( cfg_cs )
                mmr[ addr[2:0] ] <= cpu_dout;
            if( zure_cs ) begin
                if( addr[6] )
                    strip_map[ addr[4:0] ] <= cpu_dout[0];
                else
                    zure[ addr[4:0] ] <= cpu_dout;
            end
        end
        // Apply layout
        if( layout ) begin
            // total 35*8 = 280 visible pixels: OCTAL!!
            chr_render_start <= 9'o000;
            scr_render_start <= 9'o050;
        end else begin
            // total 31*8 = 248 visible pixels: OCTAL!!
            chr_render_start <= 9'o020;
            scr_render_start <= 9'o020;
        end
    end
end

always @(*) begin
    txt_en = 0;
    if( layout ) begin
        txt_en = 0;
    end else if( strip_txt ) begin
        txt_en = strip_map[ vrender[7:3] ];
    end
end

reg last_trig, trig_nfir;
reg last_fast, last_slow;
wire slow_nmi = vdump[5];
wire fast_nmi = vdump[4];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cpu_irqn  <= 1;
        cpu_firqn <= 1;
        cpu_nmin  <= 1;
        last_LVBL <= 0;
        last_irqn <= 1;
        trig_nfir <= 1;
        last_trig <= 1;
    end else if(pxl_cen ) begin
        last_LVBL <= LVBL;
        last_irqn <= cpu_irqn;
        last_trig <= trig_nfir;

        last_fast <= fast_nmi;
        last_slow <= slow_nmi;

        // IRQ, once per frame
        if( !irq_en )
            cpu_irqn <= 1;
        else if( !LVBL && last_LVBL )
            cpu_irqn <= 0;

        // NMI, once very 16 or 32 lines
        if( !nmi_en )
            cpu_nmin <= 1;
        else if( nmi_pace ? (slow_nmi && !last_slow) : (fast_nmi && !last_fast) )
            cpu_nmin <= 0;

        // FIRQ, once every two frames
        if( !last_irqn && cpu_irqn )
            trig_nfir <= ~trig_nfir;

        if( !firq_en )
            cpu_firqn <= 1;
        else if( !last_trig && trig_nfir )
            cpu_firqn <= 0;
    end
end

// Local colour mixer
wire        txt_line;
wire [ 7:0] scr_pxl_gated = scr_pxl[7:0];
wire        obj_blank     = obj_pxl[3:0] == 4'h0;
wire        tile_blank    = vprom_data[3:0] == 4'h0;
wire        border_narrow = (hdump<9'o30 || hdump>=9'o410) && narrow_en;
wire        border_wide   = hdump<9'o20 || hdump>=9'o420;
wire        blank_area    = vdump<9'o20 || (!layout && (border_narrow||border_wide));
wire [11:0] obj_scan_addr;
wire        scrwin        = scr_pxl[8];
wire        tile_prio     = prio_en[0] & scrwin & (~prio_en[1] | ~tile_blank);
wire        no_obj        = layout && ( flip ? hdump>=9'o360 : hdump<9'o50);
wire        scr_sel       = obj_blank || no_obj || tile_prio || txt_line;

reg [7:0] vprom_addr1;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pxl_out    <= ~7'd0;
        vprom_addr <= 8'd0;
    end else begin
        vprom_addr <= scr_pxl_gated;
        vprom_addr1<= vprom_addr;
        if(pxl_cen) begin
            if( blank_area )
                pxl_out <= 7'd0;
            else begin
                pxl_out[6:5] <= pal_bank;
                if( scr_sel ) begin
                    pxl_out[4:0] <= { 1'b1, vprom_data }; // Tilemap
                    pxl_pal <= vprom_addr1[7:4];
                end else begin
                    pxl_out[4:0] <= { 1'b0, obj_pxl[3:0] }; // Object
                    pxl_pal <= obj_pxl[7:4];
                end
            end
        end
    end
end

// 005885 vertical centering (VCTR). The real 005885 has a VCTR screen-centering
// input that subtracts from its vertical counter bounds to reposition the
// picture (k005885_REFERENCE.sv:196-219: `vcnt_start <= 9'd249 - VCTR`). On
// ddribble the picture sits 16 lines (2 tile rows) below the uncentered render
// window, so model that centering as a vertical offset on the render counter
// fed to BOTH the tilemap and obj engines (so sprites track tiles). Confirmed
// vs MAME: FG title tile is tile-RAM row 3 = scanline 24, shown at frame row 24.
// 007121/contra default = no centering.
// VCTR_5885=0: scene 300 (POST boot screen, FG scroll vpos=0) aligns to MAME
// vertically with NO centering. The 16-line offset first seen on scene 1500 was
// that scene's FG vertical SCROLL (vpos in the 005885 MMR), which scene replay
// doesn't load — NOT a centering constant. So the true vertical centering is 0;
// per-scene vertical position must come from loading the MMR (vpos/strip_map).
localparam [8:0] VCTR_5885 = 9'd0;
wire [8:0] vrender_disp = MODE_5885 ? (vrender - VCTR_5885) : vrender;

// 005885 horizontal centering (HCTR). Reference k005885_REFERENCE.sv:92,357 —
// HCTR[3:0] shifts NHSY (`hsync_start - HCTR[2:0]`) to reposition the picture
// horizontally. ddribble's picture sits 6px left of MAME's, so offset the
// line-buffer READ position (shared by tilemap + obj) to move content right 6px.
// hdump-6 => content written at buffer col X is shown at screen col X+6.
// Only the read paths shift; the blank/border decisions keep the real hdump.
localparam [8:0] HCTR_5885 = 9'd6;      // ddribble horizontal-centering magnitude
wire [8:0] hdump_disp = MODE_5885 ? (hdump - HCTR_5885) : hdump;

jtddribble_5885_7121_tilemap u_tilemap(
    .rst                ( rst               ),
    .clk                ( clk               ),
    // screen
    .HS                 ( HS                ),
    .LVBL               ( LVBshort          ),
    .hpos               ( hpos              ),
    .vpos               ( vpos              ),
    .vrender            ( vrender_disp      ),
    .flip               ( flip              ),
    .scrwin_en          ( scrwin_en         ),
    .line               ( line              ),
    .line_addr          ( line_addr         ),
    .done               ( done              ),
    .scr_we             ( scr_we            ),
    .line_din           ( line_din          ),
    .scan_addr          ( scan_addr         ),
    // Text mode
    .txt_en             ( txt_en            ),
    .layout             ( layout            ),
    .no_txt             ( no_txt            ),
    .txt_line           ( txt_line          ),
    .hflip_en           ( hflip_en          ),
    .vflip_en           ( vflip_en          ),
    // SDRAM
    .rom_cs             ( rom_scr_cs        ),
    .rom_addr           ( rom_scr_addr      ),
    .rom_ok             ( rom_scr_ok        ),
    .rom_data           ( rom_scr_data      ),
    .attr_scan          ( attr_scan         ),
    .code_scan          ( code_scan         ),
    // Strip scroll
    .strip_en           ( strip_en          ),
    .strip_col          ( strip_col         ),
    .strip_pos          ( strip_pos         ),
    .strip_addr         ( strip_addr        ),
    // Configuration
    .chr_dump_start     ( chr_render_start  ),
    .scr_dump_start     ( scr_render_start  ),
    .pal_msb            ( pal_msb           ),
    .extra_mask         ( extra_mask        ),
    .extra_en           ( extra_en          ),
    .extra_bits         ( extra_bits        ),
    .tile_msb           ( tile_msb          ),
    .code9_sel          ( code9_sel         ),
    .code10_sel         ( code10_sel        ),
    .code11_sel         ( code11_sel        ),
    .code12_sel         ( code12_sel        )
);

jtddribble_5885_7121_obj #(
    .MODE_5885 ( MODE_5885 )   // 005885 sprite-attribute byte layout
) u_obj(
    .rst                ( rst               ),
    .clk                ( clk               ),
    .pxl_cen            ( pxl_cen           ),
    .HS                 ( HS                ),
    .LVBL               ( LVBshort          ),
    .vrender            ( vrender_disp      ),
    .flip               ( flip              ),
    .layout             ( layout            ),
    .done               (                   ),
    .scan_addr          ( obj_scan_addr[9:0]),
    .hdump              ( hdump_disp        ),   // H-centered read (HCTR_5885)
    .pxl                ( obj_pxl           ),
    .dump_start         ( scr_render_start  ),
    // Colour PROM
    .oprom_addr         ( oprom_addr        ),
    .oprom_data         ( oprom_data        ),
    // SDRAM
    .rom_cs             ( rom_obj_cs        ),
    .rom_addr           ( rom_obj_addr      ),
    .rom_ok             ( rom_obj_ok        ),
    .rom_data           ( rom_obj_data      ),
    .obj_scan           ( obj_scan          )
);

assign obj_scan_addr[11] = obj_page_l;
assign obj_scan_addr[10] = 1'b0;

// Timing

generate
    if( VTIMER==1 ) begin
        jtframe_vtimer #(
            .HB_START( 279 ),
            .HB_END  ( 383 ),   // 384 pixels per line, H length = 64us
            .VB_END  ( 15  ),
            .VCNT_END( 261 ),   // 262 lines/frame — k005885_REFERENCE.sv:191,266
                                //   ("262 vertical lines"); was kicker's 264.
            .HS_START( 312 ),
            .VS_START( 253 ),
            .VS_END  ( 256 )
        ) u_timer(
            .clk        ( clk           ),
            .pxl_cen    ( pxl_cen       ),
            .vdump      ( vdump         ),
            .vrender    ( vrender       ),
            .vrender1   ( vrender1      ),
            .H          ( hdump         ),
            .Hinit      (               ),
            .Vinit      (               ),
            .LHBL       ( LHBL          ),
            .LVBL       ( LVBL          ),
            .HS         ( HS            ),
            .VS         ( VS            )
        );
    end
endgenerate


// Colour PROMs

generate
    if( BYPASS_VPROM != 0 ) begin : bypass_vprom
        assign vprom_data = BYPASS_VPROM == 2 ? vprom_addr[7:4] : vprom_addr[3:0];
    end else begin : uses_vprom
        jtframe_prom #(.DW(4),.AW(8) ) u_vprom(
            .clk        ( clk                       ),
            .cen        ( 1'b1                      ),
            .data       ( prog_data                 ),
            .rd_addr    ( vprom_addr                ),
            .wr_addr    ( prog_addr[7:0]            ),
            .we         ( prom_we & prog_addr[8]    ),
            .q          ( vprom_data                )
        );
    end
endgenerate

generate
    if( BYPASS_OPROM != 0 ) begin : bypass_oprom
        assign oprom_data = BYPASS_OPROM==2 ? oprom_addr[7:4] : oprom_addr[3:0];
    end else begin : uses_oprom
        jtframe_prom #(.DW(4),.AW(8),.ASYNC(1) ) u_oprom(
            .clk        ( clk                       ),
            .cen        ( 1'b1                      ),
            .data       ( prog_data                 ),
            .rd_addr    ( oprom_addr                ),
            .wr_addr    ( prog_addr[7:0]            ),
            .we         ( prom_we & ~prog_addr[8]   ),
            .q          ( oprom_data                )
        );
    end
endgenerate

jtframe_dual_ram #(.DW(9),.AW(10)) u_line_scr(
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( line_din  ),
    .addr0  ( line_addr ),
    .we0    ( scr_we    ),
    .q0     (           ),
    // Port 1
    .data1  (           ),
    .addr1  ( line_dump ),
    .we1    ( 1'b0      ),
    .q1     ( scr_pxl   )
);

jtframe_dual_ram #(.AW(11),.SIMFILE(SIMATTR)) u_attr_ram(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( ram_addr  ),
    .we0    ( attr_we   ),
    .q0     ( attr_dout ),
    // Port 1
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 1'b0      ),
    .q1     ( attr_scan )
);

jtframe_dual_ram #(.AW(11),.SIMFILE(SIMCODE)) u_code_ram(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( ram_addr  ),
    .we0    ( code_we   ),
    .q0     ( code_dout ),
    // Port 1
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 1'b0      ),
    .q1     ( code_scan )
);

jtframe_dual_ram #(.AW(12),.SIMFILE(SIMOBJ)) u_obj_ram(
    .clk0   ( clk24         ),
    .clk1   ( clk           ),
    // Port 0
    .data0  ( cpu_dout      ),
    .addr0  ( addr[11:0]),
    .we0    ( obj_we        ),
    .q0     ( obj_dout      ),
    // Port 1
    .data1  (               ),
    .addr1  ( obj_scan_addr ),
    .we1    ( 1'b0          ),
    .q1     ( obj_scan      )
);

// `ifdef SIMULATION
// always @(posedge obj_we) begin
//     if( addr[10] ) begin
//         $display("K007121 extra RAM write at %04X (%02X)", addr[11:0], cpu_dout );
//     end
// end
// `endif

endmodule