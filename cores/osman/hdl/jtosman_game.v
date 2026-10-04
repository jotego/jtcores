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

    SCAFFOLD -- Osman / Cannon Dancer, Data East "Simple 156" (simpl156.cpp).
    Structural skeleton: submodules are stubs (tie-offs). See doc/STATUS.md.
    ARM DE156 spine reuses vendored Amber (hdl/amber); video reuses cninja's
    jtcninja_deco16 (x2 pf) + jtcninja_decospr.
*/
module jtosman_game(
    `include "jtframe_game_ports.inc"
);

// ---- CPU (ARM, 16-bit device side) bus to video/palette/sprite ----
wire [16:1] cpu_addr;
wire        cpu_rnw;
wire [ 1:0] dsn;

// ---- video chip-selects + read-back ----
wire        pf_cs, pfram_cs, pal_cs, oram_cs, rowscr_cs, obj_copy;
wire [15:0] pf_dout;
wire [ 8:0] vdump;
wire        flip;

// ---- sound: main drives the two OKIs directly (no sound CPU) ----
wire        oki1_wr, oki2_wr;
wire [ 7:0] oki_din, oki1_dout, oki2_dout;
wire [ 2:0] oki2_bank;

assign dip_flip   = flip;
assign debug_view = 8'd0;

// ---- CPU side of the mem.yaml board BRAMs ----
assign palrw_addr  = cpu_addr[11:2];
assign palrw_we    = {2{pal_cs    & ~cpu_rnw}} & ~dsn;
assign palhrw_addr = cpu_addr[11:2];
assign palhrw_we   = {2{pal_cs    & ~cpu_rnw & pal888}};      // full dword writes only (hvysmsh)
assign oramrw_addr = cpu_addr[12:2];
assign oramrw_we   = {2{oram_cs   & ~cpu_rnw}} & ~dsn;
assign rs1rw_addr  = cpu_addr[12:2];
assign rs1rw_we    = {2{rowscr_cs & ~cpu_addr[14] & ~cpu_rnw}} & ~dsn;
assign rs2rw_addr  = cpu_addr[12:2];
assign rs2rw_we    = {2{rowscr_cs &  cpu_addr[14] & ~cpu_rnw}} & ~dsn;

// ---- header: one-hot family bits (cninja pattern); the decode lives in HDL ----
wire jm, cr, md, mdp, cn, hv;
wire oki1_bank;
jtosman_header u_header(
    .clk       ( clk            ),
    .header    ( header         ),
    .prog_we   ( prog_we        ),
    .prog_addr ( prog_addr[3:0] ),
    .prog_data ( prog_data      ),
    .jm(jm), .cr(cr), .md(md), .mdp(mdp), .cn(cn), .hv(hv)
);
// Per-family behaviour, derived - no game tables in the MRA:
wire tile1mb = jm|cr|md|mdp;        // 1MB plain tile region (else 2MB w/ ROM_CONTINUE swap)
wire mus2m   = jm|cr|md|mdp|hv;     // music OKI at 28/14 = 2 MHz (Mitchell = 1 MHz)
wire musraw  = hv;                  // music OKI without the init_simpl156 bitswap
wire sfxbank = hv;                  // 512KB banked sfx OKI
wire pal888  = hv;                  // xBGR888 32-bit palette

// ---- ROM download remap. prog_addr = 16-bit-WORD address, per-bank. ----
// BA1 tiles: mcf-00 is a 2 MB ROM with ROM_CONTINUE (b0->0, b1->0x100000, b2->0x80000, b3->0x180000).
// mame2mra loads it in file order (b0,b1,b2,b3); undo the ROM_CONTINUE by swapping the two middle
// 0x80000-byte blocks == swap word-address bits [19] and [18]. deco56 decrypt then sees MAME's
// post-load region layout, so the address table + the RGN_FRAC(1,2) plane split at +0x80000 line up.
// BA3 sprites: 8 MB RGN_FRAC(1,2) — FRAC0 (first 4 MB) = planes 2,3; FRAC1 (2nd 4 MB) = planes 0,1.
// decospr wants a 32-bit word byte-p=plane-p, so interleave the halves: rotate the FRAC bit
// (prog_addr[21]) down to the 32-bit-word low/high select (bit 0). FRAC1->low16 (planes 0,1),
// FRAC0->high16 (planes 2,3). Region fills the 8 MB slot -> no fold-back.
// okimusic address descramble (init_simpl156) is applied on the read side in jtosman_snd, not here.
// The header downloads before any bank data, so its values are valid here.
// BA1: the 2MB-tile boards (tile1mb=0: Mitchell + hvysmsh) hold tiles in one mask ROM
// with ROM_CONTINUE quarters -> undo by swapping word bits 19/18; 1MB boards load plain.
// BA3: sprite FRAC half interleave; the half bit (sprbit) moves with region size.
always @* begin
    post_addr = prog_addr;
    post_data = prog_data;
    if( prog_ba==2'd1 && !tile1mb ) begin
        post_addr[19] = prog_addr[18];
        post_addr[18] = prog_addr[19];
    end
    // sprite FRAC half bit by region size: 1MB (joemacr) bit18, 2MB (chainrec
    // family + charlien) bit19, 8MB (Mitchell + hvysmsh) bit21
    if( prog_ba==2'd3 )
        post_addr = jm          ? { prog_addr[21:19], prog_addr[17:0], ~prog_addr[18] } :
                    (cr|md|mdp|cn) ? { prog_addr[21:20], prog_addr[18:0], ~prog_addr[19] } :
                                   { prog_addr[20:0], ~prog_addr[21] };
end

/* verilator tracing_off */
jtosman_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .jm(jm), .cr(cr), .md(md), .mdp(mdp), .hv(hv),
    .oki1_bank  ( oki1_bank ),
    .mram_addr  ( mram_addr ),
    .mram_we    ( mram_we   ),
    .mram_dout  ( mram_dout ),
    .cen_arm    ( cen_arm   ),
    .LVBL       ( LVBL      ),
    // program ROM (SDRAM, deco156 decrypt-at-fetch)
    .rom_cs     ( main_cs   ),
    .rom_addr   ( main_addr ),
    .rom_data   ( main_data ),
    .rom_ok     ( main_ok   ),
    // CPU bus
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_rnw    ( cpu_rnw   ),
    .dsn        ( dsn       ),
    // video interface
    .pf_cs      ( pf_cs     ),
    .pfram_cs   ( pfram_cs  ),
    .pal_cs     ( pal_cs    ),
    .oram_cs    ( oram_cs   ),
    .rowscr_cs  ( rowscr_cs ),
    .obj_copy   ( obj_copy  ),
    .pf_dout    ( pf_dout   ),
    .pal_dout   ( palrw_dout  ),
    .oram_dout  ( oramrw_dout ),
    .flip       ( flip      ),
    // sound command (to OKIs)
    .oki1_wr    ( oki1_wr   ),
    .oki2_wr    ( oki2_wr   ),
    .oki_din    ( oki_din   ),
    .oki2_bank  ( oki2_bank ),
    .oki1_dout  ( oki1_dout ),
    .oki2_dout  ( oki2_dout ),
    // cabinet
    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .cab_1p     ( cab_1p    ),
    .coin       ( coin      ),
    .service    ( service   ),
    .dip_test   ( dip_test  ),
    .vdump      ( vdump     )
);

/* verilator tracing_off */
jtosman_snd u_snd(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_oki1   ( cen_oki1  ),
    .cen_oki2   ( mus2m ? cen_oki2b : cen_oki2 ),  // DECO PCBs + hvysmsh: music OKI at 2 MHz
    .oki1_bank  ( oki1_bank & sfxbank ),
    .musraw     ( musraw    ),
    .din        ( oki_din   ),
    .oki1_wr    ( oki1_wr   ),
    .oki2_wr    ( oki2_wr   ),
    .oki2_bank  ( oki2_bank ),
    .oki1_dout  ( oki1_dout ),
    .oki2_dout  ( oki2_dout ),
    // OKI #1 sample ROM (SDRAM)
    .rom1_cs    ( oki1_cs   ),
    .rom1_addr  ( oki1_addr ),
    .rom1_data  ( oki1_data ),
    .rom1_ok    ( oki1_ok   ),
    // OKI #2 sample ROM (SDRAM)
    .rom2_cs    ( oki2_cs   ),
    .rom2_addr  ( oki2_addr ),
    .rom2_data  ( oki2_data ),
    .rom2_ok    ( oki2_ok   ),
    .pcm1       ( pcm1      ),
    .pcm2       ( pcm2      )
);

/* verilator tracing_off */
jtosman_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),
    .gfx_en     ( gfx_en    ),
    .flip       ( flip      ),
    .tile1mb    ( tile1mb   ),
    .pal888     ( pal888    ),
    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_rnw    ( cpu_rnw   ),
    .dsn        ( dsn       ),
    .pf_cs      ( pf_cs     ),
    .pfram_cs   ( pfram_cs  ),
    .obj_copy   ( obj_copy  ),
    .pf_dout    ( pf_dout   ),
    // board BRAMs (mem.yaml): engine-side read buses
    .pal_rd     ( pal_rd    ),
    .pal_dout   ( pal_dout  ),
    .palh_dout  ( palh_dout ),
    .obj_oaddr  ( obj_oaddr ),
    .oram_dout  ( oram_dout ),
    .pf1_rsa    ( pf1_rsa   ),
    .rs1_dout   ( rs1_dout  ),
    .pf2_rsa    ( pf2_rsa   ),
    .rs2_dout   ( rs2_dout  ),
    // tile gfx ROM (BA1, deco56 decrypt-at-fetch)
    .gfx1a_cs   ( gfx1a_cs  ),
    .gfx1a_addr ( gfx1a_addr),
    .gfx1a_data ( gfx1a_data),
    .gfx1a_ok   ( gfx1a_ok  ),
    .gfx1b_cs   ( gfx1b_cs  ),
    .gfx1b_addr ( gfx1b_addr),
    .gfx1b_data ( gfx1b_data),
    .gfx1b_ok   ( gfx1b_ok  ),
    .gfx1c_cs   ( gfx1c_cs  ),
    .gfx1c_addr ( gfx1c_addr),
    .gfx1c_data ( gfx1c_data),
    .gfx1c_ok   ( gfx1c_ok  ),
    .gfx1d_cs   ( gfx1d_cs  ),
    .gfx1d_addr ( gfx1d_addr),
    .gfx1d_data ( gfx1d_data),
    .gfx1d_ok   ( gfx1d_ok  ),
    // sprite gfx ROM (BA3)
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),
    .obj_ok     ( obj_ok    ),
    // timing / output
    .vdump      ( vdump     ),
    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

endmodule
