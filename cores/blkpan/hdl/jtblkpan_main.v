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

    // Video board
    output     [15:1] o_addr,
    output     [15:0] o_dout,
    input      [15:0] i_video_din,
    output            o_rw_n, o_uds_n, o_lds_n,
    output            o_chacs_n, o_objram_n, o_vcs1, o_vcs2, o_vzcs,
    output            o_hflip, o_vflip,
    input             i_vbl,          // active high during vertical blanking
    input             i_clk6, i_h1_n, i_h2,

    // Palette (xBGR_555, 2048 entries in BRAM)
    output     [10:0] o_pal_addr,
    output     [ 1:0] o_pal_we,
    input      [15:0] i_pal_dout,

    // Sound board
    output reg [ 7:0] o_snd_latch,
    output            o_snd_irq,      // rising edge -> Z80 IRQ (7474)

    // Cabinet. Active HIGH on this board (MAME IP_ACTIVE_HIGH), already
    // corrected in the game module.
    input      [ 7:0] i_in0, i_in1, i_in2, i_dsw0, i_dsw1,

    // ROM
    output            o_rom_cs,
    output     [18:1] o_rom_addr,
    input      [15:0] i_rom_data,
    input             i_rom_ok,

    output            o_ram_cs,
    output            o_ram_we,
    output     [ 1:0] o_ram_dsn,
    output     [14:1] o_ram_addr,
    input      [15:0] i_ram_data,
    input             i_ram_ok
);

wire [23:1] cpu_addr;
wire [15:0] cpu_dout;
reg  [15:0] cpu_din;
wire        as_n, rw_n, uds_n, lds_n;
wire        FC0, FC1, FC2;
wire        rom_cs, ram_cs, pal_cs, outlatch_cs, intlatch_cs, snd_cs, wdog_cs,
            dsw0_cs, dsw1_cs, in0_cs, in1_cs, in2_cs;
wire        chacs_n, objram_n, vcs1, vcs2, vzcs;
wire        lanes_idle = uds_n && lds_n;

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
assign o_rom_cs  = rom_cs && !rst && !lanes_idle;
assign o_ram_addr= cpu_addr[14:1];
assign o_ram_cs  = ram_cs && !rst && !lanes_idle;
assign o_ram_we  = o_ram_cs && !rw_n;
// The SDRAM slot uses both byte lanes during its reset erase.
assign o_ram_dsn = o_ram_cs ? { uds_n, lds_n } : 2'b00;

`ifndef NOMAIN


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

    .o_rom_cs      ( rom_cs      ),
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
// Latches at 0a0000 (upper lane) / 0a0001 (lower lane).
// outlatch: b1,b2 = coin lockout (unused here), b3 = Z80 IRQ via a 7474.
//   NOTE this is bit 3 on the Salamander-class board; Nemesis uses bit 2.
// intlatch: MAME applies bitswap<8>(d,7,6,5,4,3,2,0,1) before salamand's
//   handler, i.e. irq1/irq2 are swapped -> b0 = irq2 enable, b1 = irq1 enable,
//   b2 = flip X, b3 = flip Y.
// ---------------------------------------------------------------------------
reg       irq1_en, irq2_en, flipx, flipy;
reg [7:0] outlatch;

assign o_hflip = flipx;
assign o_vflip = flipy;
assign o_snd_irq = outlatch[3];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        outlatch  <= 0;
        irq1_en   <= 0;
        irq2_en   <= 0;
        flipx     <= 0;
        flipy     <= 0;
    end else begin
        if( outlatch_cs && !rw_n ) outlatch <= cpu_dout[15:8];
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
wire [2:0] ipl_n;
wire       irq2;

jtframe_edge u_irq2(
    .rst    ( rst      ),
    .clk    ( clk      ),
    .edgeof ( i_vbl    ),
    .clr    ( ~irq2_en ),
    .q      ( irq2     )
);

assign ipl_n = irq2 && !rst ? 3'b101 : 3'b111;

// VPAn low during an interrupt acknowledge gives the autovector. The 68000
// drives A[23:4] high in that cycle, so keying on A23 covers it (same trick as
// the Nemesis board).
wire vpa_n = |{ ~cpu_addr[23], as_n };

// ---------------------------------------------------------------------------
// DTACK
// ---------------------------------------------------------------------------
wire        DTACKn, cpu_cen, cpu_cenb;
wire        scroll_obj_cs = !vzcs || !objram_n;
wire        vram_char_cs = !vcs1 || !vcs2 || !chacs_n;
wire        vram_slot = !i_clk6 && i_h1_n && !i_h2;
wire        io_dtack_n, scroll_obj_dtack_n, vram_char_dtack_n;
wire        bus_legit = scroll_obj_cs || vram_char_cs || !vpa_n;
wire        bus_busy = !vpa_n || (rom_cs && !i_rom_ok) || (ram_cs && !i_ram_ok) ||
                      (scroll_obj_cs && scroll_obj_dtack_n) || (vram_char_cs && vram_char_dtack_n);

jtframe_ff u_io_dtack(
    .rst     ( rst        ),
    .clk     ( clk        ),
    .cen     ( 1'b1       ),
    .sigedge ( i_clk6     ),
    .set     ( lanes_idle ),
    .clr     ( 1'b0       ),
    .din     ( lanes_idle ),
    .q       ( io_dtack_n ),
    .qn      (            )
);

jtframe_ff u_scroll_obj_dtack(
    .rst     ( rst                ),
    .clk     ( clk                ),
    .cen     ( 1'b1               ),
    .sigedge ( i_h1_n             ),
    .set     ( lanes_idle         ),
    .clr     ( 1'b0               ),
    .din     ( lanes_idle         ),
    .q       ( scroll_obj_dtack_n ),
    .qn      (                    )
);

jtframe_ff u_vram_char_dtack(
    .rst     ( rst                ),
    .clk     ( clk                ),
    .cen     ( 1'b1               ),
    .sigedge ( vram_slot          ),
    .set     ( lanes_idle         ),
    .clr     ( 1'b0               ),
    .din     ( io_dtack_n         ),
    .q       ( vram_char_dtack_n  ),
    .qn      (                    )
);

jtframe_68kdtack_cen #(
    .W        ( 5 ),
    .RECOVERY ( 1 )
) u_dtack(
    .rst       ( rst              ),
    .clk       ( clk              ),
    .cpu_cen   ( cpu_cen          ),
    .cpu_cenb  ( cpu_cenb         ),
    .bus_cs    ( 1'b1             ),
    .bus_busy  ( bus_busy         ),
    .bus_legit ( bus_legit        ),
    .bus_ack   ( 1'b0             ),
    .RnW       ( rw_n             ),
    .BGACKn    ( 1'b1             ),
    .ASn       ( as_n             ),
    .DSn       ( { uds_n, lds_n } ),
    .num       ( 4'd3             ),
    .den       ( 5'd16            ),
    .waitn     ( 2'd0             ),
    .DTACKn    ( DTACKn           ),
    .fave      (                  ),
    .fworst    (                  )
);

// ---------------------------------------------------------------------------
// CPU data in
// ---------------------------------------------------------------------------
always @(*) begin
    cpu_din = 16'hffff;
    case( 1'b1 )
        rom_cs:      cpu_din = i_rom_data;
        ram_cs:      cpu_din = i_ram_data;
        outlatch_cs: cpu_din = { outlatch, 8'hff };
        pal_cs:      cpu_din = { 8'hff, cpu_addr[1] ? i_pal_dout[7:0] : i_pal_dout[15:8] };
        dsw0_cs:     cpu_din = { i_dsw0, i_dsw0 };
        dsw1_cs:     cpu_din = { i_dsw1, i_dsw1 };
        in0_cs:      cpu_din = { i_in0,  i_in0  };
        in1_cs:      cpu_din = { i_in1,  i_in1  };
        in2_cs:      cpu_din = { i_in2,  i_in2  };
        default:
            if( !chacs_n || !objram_n || !vcs1 || !vcs2 || !vzcs )
                cpu_din = i_video_din;
    endcase
end

// ---------------------------------------------------------------------------
// CPU
// ---------------------------------------------------------------------------
fx68k u_cpu(
    .clk        ( clk         ),
    .extReset   ( rst         ),
    .pwrUp      ( rst         ),
    .enPhi1     ( cpu_cen     ),
    .enPhi2     ( cpu_cenb    ),
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
assign rom_cs = 0;
assign ram_cs = 0, pal_cs = 0, outlatch_cs = 0, intlatch_cs = 0, snd_cs = 0;
assign wdog_cs = 0, dsw0_cs = 0, dsw1_cs = 0, in0_cs = 0, in1_cs = 0, in2_cs = 0;
assign chacs_n = 1, objram_n = 1, vcs1 = 1, vcs2 = 1, vzcs = 1;
assign o_pal_addr = 11'd0, o_pal_we = 2'd0;
assign o_hflip = 0, o_vflip = 0;
assign o_snd_irq = 0;
initial o_snd_latch = 0;

`endif

endmodule
