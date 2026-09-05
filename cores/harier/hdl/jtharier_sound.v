/* SPDX-FileCopyrightText: 2026 Chris Watson/Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-8-2026 */

// Sound board 834-5799 (bare PCB 171-5268), schematic sheets D-1/3 .. D-3/3.
//
// Z80A + YM2203 + discrete SegaPCM. A 16.000 MHz oscillator feeds ALS109
// dividers giving the 8M and 4M rails (sheet D-1/3); the Z80 and YM2203 run
// from 4M. The PCM is discrete -- a 315-5103 sequencer, DAC7022/AD7520, HC4066
// demux and two MF6-50 filters (sheets D-2/3, D-3/3) -- and is segapcm_device<8>,
// the same class as Out Run's sixteen-voice part, so jtoutrun_pcm is reused.

module jtharier_sound(
    input                snd_rstn,      // PPI0 port B bit 5, held low by the 68000
    input                clk,

    input                cen_fm,    // 4 MHz, YM2203 (sheet D-2/3, pin 38 OM from 4M)
    input                cen_pcm,   // 16 MHz -- NOT 8. See the PCM section below.

    // Main CPU interface via PPI0, CPU sheet 2/6
    input        [ 7:0]  latch,     // PPI0 port A, written by the 68000
    input                nmi_n,     // PPI0 port C bit 7 = /OBF, active low
    output               latch_rd,  // -> PPI0 port C bit 6, /ACK

    // Program ROM EPR-7233 IC72 + EPR-7234 IC73, 32 kB
    output       [14:0]  rom_addr,
    output reg           rom_cs,
    input        [ 7:0]  rom_data,
    input                rom_ok,

    // PCM sample ROM EPR-7231 IC5 + EPR-7232 IC6
    output       [15:0]  pcm_addr,
    output               pcm_cs,
    input        [ 7:0]  pcm_data,
    input                pcm_ok,

    output signed [15:0] fm_snd,
    output        [ 9:0] psg_snd,
    output signed [15:0] pcm_l,
    output signed [15:0] pcm_r
);
`ifndef NOSOUND
wire [15:0] A;
wire [ 7:0] cpu_dout, ram_dout, fm_dout, pcm_dout;
wire        mreq_n, iorq_n, rd_n, wr_n, rfsh_n, int_n;
reg  [ 7:0] cpu_din;
reg         ram_cs, fm_cs, pcm_cs_l, latch_cs, snd_rst;

assign rom_addr = A[14:0];
assign latch_rd = latch_cs;

always @(posedge clk) begin
    snd_rst <= ~snd_rstn;
end

always @(*) begin
    rom_cs   = !mreq_n && rfsh_n && !A[15];
    ram_cs   = !mreq_n && rfsh_n &&  A[15:12]==4'hc;
    fm_cs    = !mreq_n && rfsh_n &&  A[15:12]==4'hd;
    pcm_cs_l = !mreq_n && rfsh_n &&  A[15:12]==4'he;
    latch_cs = !iorq_n &&  !rd_n &&  A[ 7: 6]==2'h1;
end

always @(*) begin
    cpu_din = rom_cs   ? rom_data :
              ram_cs   ? ram_dout :
              fm_cs    ? fm_dout  :
              pcm_cs_l ? pcm_dout :
              latch_cs ? latch    : 8'hff;
end

// PPI0 port A is a MODE 1 strobed-output port: the 68000 writing a command
// asserts /OBF (port C bit 7), which is the Z80's NMI, and /OBF releases only on
// /ACK (port C bit 6) -- here the Z80 reading the latch, exported as latch_rd.
// Without that path the 8255 sends exactly ONE NMI and stops forever.
jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n      ( snd_rstn    ),
    .clk        ( clk         ),
    .cen        ( cen_fm      ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( cpu_din     ),
    .cpu_dout   ( cpu_dout    ),
    .ram_dout   ( ram_dout    ),
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);

jt03 u_fm(
    .rst        ( snd_rst     ),
    .clk        ( clk         ),
    .cen        ( cen_fm      ),
    .din        ( cpu_dout    ),
    .addr       ( A[0]        ),
    .cs_n       ( ~fm_cs      ),
    .wr_n       ( wr_n        ),
    .dout       ( fm_dout     ),
    .irq_n      ( int_n       ),

    .psg_snd    ( psg_snd     ),
    .fm_snd     ( fm_snd      ),
    .snd_sample (             ),

    // Unused:
    .IOA_in     ( 8'd0        ),
    .IOB_in     ( 8'd0        ),
    .IOA_out    (             ),
    .IOB_out    (             ),
    .IOA_oe     (             ),
    .IOB_oe     (             ),
    .psg_A      (             ),
    .psg_B      (             ),
    .psg_C      (             ),
    .snd        (             ),
    .debug_view (             )
);


// Stock jtoutrun_pcm, WD at its default 12, and the PCM audibly distorts as a
// result: clipDAC() saturates each voice before accumulating, but WD is the FINAL
// DAC width and that DAC converts the sum. The product (rom_data-0x80) * vol spans
// +/-16256 and needs 15 bits, so 12 saturates eight times too early -- this driver
// writes volumes up to 0x3F, so everything above a quarter amplitude distorts.
// segapcm.cpp accumulates unclipped. Left as-is at jotego's request: he asked to
// hear the PCM with the problem present rather than the WD(16) parameter that
// removes it.
wire [ 2:0] nc;

jtoutrun_pcm u_pcm(
    .rst        ( snd_rst     ),
    .clk        ( clk         ),
    .cen        ( cen_pcm     ),

    .cpu_addr   ( A[7:0]      ),
    .cpu_dout   ( cpu_dout    ),
    .cpu_din    ( pcm_dout    ),
    .cpu_rnw    ( wr_n        ),
    .cpu_cs     ( pcm_cs_l    ),

    .rom_addr   ({nc,pcm_addr}),
    .rom_data   ( pcm_data    ),
    .rom_ok     ( pcm_ok      ),
    .rom_cs     ( pcm_cs      ),

    .snd_left   ( pcm_l       ),
    .snd_right  ( pcm_r       ),
    .sample     (             ),

    .debug_bus  ( 8'd0        ),
    .st_dout    (             )
);
`else
assign latch_rd = 0;
assign rom_addr = 0;
assign pcm_addr = 0;
assign pcm_cs   = 0;
assign fm_snd   = 0;
assign psg_snd  = 0;
assign pcm_l    = 0;
assign pcm_r    = 0;
initial rom_cs  = 0;
`endif

endmodule
