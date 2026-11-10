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
    Date: 2026 */

// 68000 board for Konami GX604 (Black Panther), 9.216MHz (18.432/2).
// Transcribed from MAME nemesis.cpp (salamand_state, blkpnthr_* members).

`default_nettype none

module jtblkpan_main(
    input             clk,
    input             rst,
    input             cen9,

    // Video board
    output     [15:1] o_addr,
    output     [15:0] o_dout,
    input      [15:0] i_video_din,
    output            o_rw_n, o_uds_n, o_lds_n,
    output            o_chacs_n, o_objram_n, o_vcs1, o_vcs2, o_vzcs,
    output            o_hflip, o_vflip,
    input             i_vbl,          // active high during vertical blanking

    // Palette (xBGR_555, 2048 entries in BRAM)
    output     [10:0] o_pal_addr,
    output     [ 1:0] o_pal_we,
    input      [15:0] i_pal_dout,

    // Sound board
    output reg [ 7:0] o_snd_latch,
    output reg        o_snd_irq,      // rising edge -> Z80 IRQ (7474)

    // Cabinet. Active HIGH on this board (MAME IP_ACTIVE_HIGH), already
    // corrected in the game module.
    input      [ 7:0] i_in0, i_in1, i_in2, i_dsw0, i_dsw1,

    // ROM
    output            o_rom_cs,
    output     [18:1] o_rom_addr,
    input      [15:0] i_rom_data,
    input             i_rom_ok
);

wire [23:1] cpu_addr;
wire [15:0] cpu_dout;
reg  [15:0] cpu_din;
wire        as_n, rw_n, uds_n, lds_n;
wire        FC0, FC1, FC2;
wire        ram_cs, pal_cs, outlatch_cs, intlatch_cs, snd_cs, wdog_cs,
            dsw0_cs, dsw1_cs, in0_cs, in1_cs, in2_cs;
wire        chacs_n, objram_n, vcs1, vcs2, vzcs;

assign o_addr    = cpu_addr[15:1];
assign o_dout    = cpu_dout;
assign o_rw_n    = rw_n;
assign o_uds_n   = uds_n;
assign o_lds_n   = lds_n;
assign o_chacs_n = chacs_n;
assign o_objram_n= objram_n;
assign o_vcs1    = vcs1;
assign o_vcs2    = vcs2;
assign o_vzcs    = vzcs;
assign o_rom_addr= cpu_addr[18:1];

`ifndef NOMAIN


wire        UDSWn   = rw_n | uds_n;
wire        LDSWn   = rw_n | lds_n;
wire [ 1:0] dsn     = { uds_n, lds_n };

// Palette: MAME keeps it byte-wide on the low lane (umask 0x00ff, membits 8),
// so one 68000 word address holds one palette BYTE. a[1] picks which half of
// the 16-bit entry, a[12:2] is the colour index.
// MAME's palette share lives in the 68000's BIG-endian space and no
// set_endianness() overrides it, so memory_array::read16_from_8be applies:
//     colour[i] = (byte[2i] << 8) | byte[2i+1]
// i.e. the EVEN palette byte (A1=0) is the HIGH half of the entry. Blue sits
// entirely in that half, so getting this backwards costs you the blue channel.
assign o_pal_addr = cpu_addr[12:2];
assign o_pal_we   = { 2{ pal_cs & ~rw_n & ~lds_n } } & { ~cpu_addr[1], cpu_addr[1] };

jtblkpan_addr_dec u_dec(
    .i_as_n        ( as_n        ),
    .i_lds_n       ( lds_n       ),
    .i_uds_n       ( uds_n       ),
    .i_cpu_addr    ( cpu_addr    ),

    .o_rom_cs      ( o_rom_cs    ),
    .o_ram_cs      ( ram_cs      ),
    .o_pal_cs      ( pal_cs      ),
    .o_outlatch_cs ( outlatch_cs ),
    .o_intlatch_cs ( intlatch_cs ),
    .o_snd_cs      ( snd_cs      ),
    .o_wdog_cs     ( wdog_cs     ),
    .o_dsw0_cs     ( dsw0_cs     ),
    .o_in0_cs      ( in0_cs      ),
    .o_in1_cs      ( in1_cs      ),
    .o_in2_cs      ( in2_cs      ),
    .o_dsw1_cs     ( dsw1_cs     ),
    .o_chacs_n     ( chacs_n     ),
    .o_objram_n    ( objram_n    ),
    .o_vcs1        ( vcs1        ),
    .o_vcs2        ( vcs2        ),
    .o_vzcs        ( vzcs        )
);

// ---------------------------------------------------------------------------
// Work RAM: 32kB at 090000-097fff
// ---------------------------------------------------------------------------
wire [7:0] ram_lo, ram_hi;

jtframe_ram #(.AW(14),.DW(8)) u_ram_lo(
    .clk ( clk ), .cen ( 1'b1 ),
    .addr( cpu_addr[14:1] ), .data( cpu_dout[ 7:0] ),
    .we  ( ram_cs & ~LDSWn ), .q( ram_lo )
);

jtframe_ram #(.AW(14),.DW(8)) u_ram_hi(
    .clk ( clk ), .cen ( 1'b1 ),
    .addr( cpu_addr[14:1] ), .data( cpu_dout[15:8] ),
    .we  ( ram_cs & ~UDSWn ), .q( ram_hi )
);

// ---------------------------------------------------------------------------
// Latches at 0a0000 (upper lane) / 0a0001 (lower lane).
// outlatch: b1,b2 = coin lockout (unused here), b3 = Z80 IRQ via a 7474.
//   NOTE this is bit 3 on the Salamander-class board; Nemesis uses bit 2.
// intlatch: MAME applies bitswap<8>(d,7,6,5,4,3,2,0,1) before salamand's
//   handler, i.e. irq1/irq2 are swapped -> b0 = irq2 enable, b1 = irq1 enable,
//   b2 = flip X, b3 = flip Y.
// ---------------------------------------------------------------------------
reg irq1_en, irq2_en, flipx, flipy;

assign o_hflip = flipx;
assign o_vflip = flipy;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        o_snd_irq <= 0;
        irq1_en   <= 0;
        irq2_en   <= 0;
        flipx     <= 0;
        flipy     <= 0;
    end else begin
        if( outlatch_cs && !rw_n ) o_snd_irq <= cpu_dout[11];   // b3 of the upper byte
        if( intlatch_cs && !rw_n ) begin
            irq2_en <= cpu_dout[0];
            irq1_en <= cpu_dout[1];
            flipx   <= cpu_dout[2];
            flipy   <= cpu_dout[3];
        end
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) o_snd_latch <= 0;
    else if( snd_cs && !rw_n ) o_snd_latch <= cpu_dout[7:0];
end

// ---------------------------------------------------------------------------
// Interrupts. Black Panther takes IRQ2 on vblank (salamand_state::vblank_irq2);
// IRQ1 exists on the board but this game does not enable it.
// ---------------------------------------------------------------------------
reg  [2:0] ipl_n;
reg        irq2, vbl_l;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        irq2  <= 0;
        vbl_l <= 0;
    end else begin
        vbl_l <= i_vbl;
        // MAME asserts IRQ2 on the vblank edge and clears it ONLY through
        // irq2_enable_w(0) -- never on interrupt acknowledge. Clearing on ack
        // here killed the request before the CPU could take it, and the game
        // spun forever in its vblank wait loop at PC 0x000B8C.
        if( i_vbl && !vbl_l && irq2_en ) irq2 <= 1;
        if( !irq2_en                   ) irq2 <= 0;
    end
end

always @(*) ipl_n = irq2 ? 3'b101 : 3'b111;   // level 2

// VPAn low during an interrupt acknowledge gives the autovector. The 68000
// drives A[23:4] high in that cycle, so keying on A23 covers it (same trick as
// the Nemesis board).
wire vpa_n = |{ ~cpu_addr[23], as_n };

// ---------------------------------------------------------------------------
// DTACK
// ---------------------------------------------------------------------------
reg DTACKn;

always @(posedge clk, posedge rst) begin
    if( rst ) DTACKn <= 1;
    // VPAn low means the 68000 is autovectoring (interrupt acknowledge, or the
    // A23 window): it uses VPA instead of DTACK, so keep DTACK negated there.
    else if( as_n || !vpa_n ) DTACKn <= 1;
    else DTACKn <= o_rom_cs ? ~i_rom_ok : 1'b0;
end

// ---------------------------------------------------------------------------
// CPU data in
// ---------------------------------------------------------------------------
always @(*) begin
    cpu_din = 16'hffff;
    case( 1'b1 )
        o_rom_cs: cpu_din = i_rom_data;
        ram_cs:   cpu_din = { ram_hi, ram_lo };
        pal_cs:   cpu_din = { 8'hff, cpu_addr[1] ? i_pal_dout[7:0] : i_pal_dout[15:8] };
        dsw0_cs:  cpu_din = { i_dsw0, i_dsw0 };
        dsw1_cs:  cpu_din = { i_dsw1, i_dsw1 };
        in0_cs:   cpu_din = { i_in0,  i_in0  };
        in1_cs:   cpu_din = { i_in1,  i_in1  };
        in2_cs:   cpu_din = { i_in2,  i_in2  };
        default:
            if( !chacs_n || !objram_n || !vcs1 || !vcs2 || !vzcs )
                cpu_din = i_video_din;
    endcase
end

// ---------------------------------------------------------------------------
// CPU
// ---------------------------------------------------------------------------
reg cen9d, cen9b;

always @(posedge clk) begin : cen_dly
    reg cen9x;
    cen9d <= cen9;
    cen9x <= cen9d;
    cen9b <= cen9x;
end

fx68k u_cpu(
    .clk        ( clk         ),
    .extReset   ( rst         ),
    .pwrUp      ( rst         ),
    .enPhi1     ( cen9d       ),
    .enPhi2     ( cen9b       ),
    .HALTn      ( ~rst        ),

    .eab        ( cpu_addr    ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),

    .eRWn       ( rw_n        ),
    .LDSn       ( lds_n       ),
    .UDSn       ( uds_n       ),
    .ASn        ( as_n        ),
    .VPAn       ( vpa_n       ),
    .BERRn      ( 1'b1        ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .DTACKn     ( DTACKn      ),
    .IPL0n      ( ipl_n[0]    ),
    .IPL1n      ( ipl_n[1]    ),
    .IPL2n      ( ipl_n[2]    ),

    .BGn        (             ),
    .FC0        ( FC0         ),
    .FC1        ( FC1         ),
    .FC2        ( FC2         ),
    .oRESETn    (             ),
    .oHALTEDn   (             ),
    .VMAn       (             ),
    .E          (             )
);

`else

assign as_n = 1, rw_n = 1, uds_n = 1, lds_n = 1;
assign FC0 = 0, FC1 = 0, FC2 = 0;
assign cpu_addr = 23'd0, cpu_dout = 16'd0;
assign o_rom_cs = 0;
assign ram_cs = 0, pal_cs = 0, outlatch_cs = 0, intlatch_cs = 0, snd_cs = 0;
assign wdog_cs = 0, dsw0_cs = 0, dsw1_cs = 0, in0_cs = 0, in1_cs = 0, in2_cs = 0;
assign chacs_n = 1, objram_n = 1, vcs1 = 1, vcs2 = 1, vzcs = 1;
assign o_pal_addr = 11'd0, o_pal_we = 2'd0;
assign o_hflip = 0, o_vflip = 0;
initial begin o_snd_latch = 0; o_snd_irq = 0; end

`endif

endmodule
