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

    Author: niknak
    Version: 1.0
    Date: 2-8-2026 */

/*  JTSHARRIER — Space Harrier sound board
    Z80 @ 4MHz + YM2203 (jt03) + SegaPCM discrete (jtsharrier_pcm).
    Simpler than Out Run: no 315-5195 mapper.

    Z80 memory map (sound_map_2203):
      0000-7FFF  ROM (32K)          rom_cs
      C000-C7FF  RAM (2K)           ram_cs
      D000-D001  YM2203             fm_cs   (A0 = reg/data)
      E000-E0FF  SegaPCM            pcm_ce
    Z80 I/O:
      port 40    sound-latch read (clears NMI)
    IRQ: YM2203 irq_n -> Z80 INT.  NMI: pulsed by main via PPI0 handshake.
*/

module jtsharrier_snd(
    input        [7:0] debug_bus,
    output       [7:0] pcm_st,     // PCM voice-activity mask, debug_bus[0] picks the byte

    input                rst,
    input                clk,
    input                snd_rstb,     // sound reset (active low), from PPI0

    input                cen_fm,       // 4 MHz  (YM2203)
    input                cen_pcm,      // SegaPCM, 16 MHz -> 62.5 kHz slot rate

    // command latch from main (PPI0 port A) + NMI handshake
    input        [ 7:0]  latch,
    input                nmi_set,      // 1-clk pulse: main posted a command

    // program ROM (SDRAM bank1 'snd')
    output       [15:0]  rom_addr,
    output reg           rom_cs,
    input        [ 7:0]  rom_data,
    input                rom_ok,

    // SegaPCM sample ROM (SDRAM bank1 'pcm') -- 64 KB, see note at u_pcm
    output       [15:0]  pcm_addr,
    input        [ 7:0]  pcm_data,
    input                pcm_ok,
    output               pcm_cs,

    // Analogue outputs, kept SEPARATE so cfg/mem.yaml's audio: section can apply
    // the real board gains (PCM 22k, FM 47k, SSG 47k into a 47k feedback).
    // Do not pre-mix these here -- that is what the mixer is for.
    output signed [15:0] fm_snd,     // YM2203 FM half, via the YM3014 DAC
    output        [ 9:0] psg_snd,    // YM2203 SSG half, unsigned (jt03_psg)
    output signed [15:0] pcm_l, pcm_r
);

wire [15:0] A;
wire        mreq_n, rfsh_n, iorq_n, m1_n, wr_n, rd_n, int_n;
wire [ 7:0] cpu_dout, ram_dout, fm_dout, pcm_dout;
reg  [ 7:0] cpu_din;
reg         ram_cs, fm_cs, pcm_ce, latch_cs;
wire        mix_rst = rst | ~snd_rstb;
wire        fm_irq_n;

// SegaPCM forms its ROM address as {bank[2:0], cur_addr[23:8]} = 19 bits. This
// board's pcm region is 64 KB (epr-7231 @0x0000 + epr-7232 @0x8000, matching
// MAME's pcm region), so cur_addr[23:8] alone spans it and the bank bits are
// always 0. Drop them explicitly rather than letting the port connection
// truncate silently.
wire [18:0] pcm_addr_full;
assign pcm_addr = pcm_addr_full[15:0];

assign rom_addr = A;

// ---- address / port decode ------------------------------------------------
always @(*) begin
    rom_cs   = !mreq_n && rfsh_n && !A[15];                 // 0000-7FFF
    ram_cs   = !mreq_n && rfsh_n && A[15:11]==5'b11000;     // C000-C7FF
    fm_cs    = !mreq_n && rfsh_n && A[15:12]==4'hD;         // D000-D001
    pcm_ce   = !mreq_n && rfsh_n && A[15:8]==8'hE0;         // E000-E0FF
    latch_cs = !iorq_n && m1_n && A[6];                     // port 0x40 read
end

// ---- NMI handshake --------------------------------------------------------
reg nmi_n;
always @(posedge clk) begin
    if( mix_rst )        nmi_n <= 1'b1;
    else begin
        if( nmi_set )                 nmi_n <= 1'b0;
        else if( latch_cs && !rd_n )  nmi_n <= 1'b1;   // reading latch clears NMI
    end
end

// ---- CPU data-in mux ------------------------------------------------------
always @(posedge clk) begin
    cpu_din <= rom_cs   ? rom_data :
               ram_cs   ? ram_dout :
               fm_cs    ? fm_dout  :
               pcm_ce   ? pcm_dout :
               latch_cs ? latch    :
                          8'hff;
end

jtframe_sysz80 #(.RAM_AW(11),.RECOVERY(1)) u_cpu(
    .rst_n    ( ~mix_rst ),
    .clk      ( clk      ),
    .cen      ( cen_fm   ),
    .cpu_cen  (          ),
    .int_n    ( fm_irq_n ),
    .nmi_n    ( nmi_n    ),
    .busrq_n  ( 1'b1     ),
    .m1_n     ( m1_n     ),
    .mreq_n   ( mreq_n   ),
    .iorq_n   ( iorq_n   ),
    .rd_n     ( rd_n     ),
    .wr_n     ( wr_n     ),
    .rfsh_n   ( rfsh_n   ),
    .halt_n   (          ),
    .busak_n  (          ),
    .A        ( A        ),
    .cpu_din  ( cpu_din  ),
    .cpu_dout ( cpu_dout ),
    .ram_dout ( ram_dout ),
    .ram_cs   ( ram_cs   ),
    .rom_cs   ( rom_cs   ),
    .rom_ok   ( rom_ok   )
);

// ---- YM2203 (FM + PSG combined on .snd) ------------------------------------
/* verilator lint_off PINMISSING */
jt03 u_fm(
    .rst      ( mix_rst  ),
    .clk      ( clk      ),
    .cen      ( cen_fm   ),
    .din      ( cpu_dout ),
    .addr     ( A[0]     ),
    .cs_n     ( ~fm_cs   ),
    .wr_n     ( wr_n     ),
    .dout     ( fm_dout  ),
    .irq_n    ( fm_irq_n ),
    .IOA_in   ( 8'hff    ),
    .IOB_in   ( 8'hff    ),
    .fm_snd   ( fm_snd   ),   // FM only, signed 16-bit  -> 47k on the PCB
    .psg_snd  ( psg_snd  ),   // SSG only, unsigned 10-bit -> 47k on the PCB
    .snd      (          ),   // jt03's own mix is unused: the board sums the two
                              // halves through separate resistors, so we hand
                              // them to jtframe's mixer separately.
    .snd_sample(          )
);
/* verilator lint_on PINMISSING */

// ---- SegaPCM (discrete variant) --------------------------------------------
// Local fork of jtoutrun_pcm: it accumulates the raw product and saturates only
// at the sum, rather than clipping each voice first. See the DIVERGENCE block
// at the top of jtsharrier_pcm.v.
jtsharrier_pcm u_pcm(
    .rst      ( mix_rst  ),
    .clk      ( clk      ),
    .cen      ( cen_pcm  ),
    .debug_bus( debug_bus ),
    .st_dout  ( pcm_st    ),
    .cpu_addr ( A[7:0]   ),
    .cpu_dout ( cpu_dout ),
    .cpu_din  ( pcm_dout ),
    .cpu_rnw  ( wr_n     ),   // wr_n high = read
    .cpu_cs   ( pcm_ce   ),
    .rom_addr ( pcm_addr_full ),
    .rom_data ( pcm_data ),
    .rom_ok   ( pcm_ok   ),
    .rom_cs   ( pcm_cs   ),
    .snd_left ( pcm_l    ),
    .snd_right( pcm_r    ),
    .sample   (          )
);

endmodule
