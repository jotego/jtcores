/* SPDX-FileCopyrightText: 2026 Chris Watson/Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-8-2026 */

module jtharier_sound(
    input                snd_rstn, // PPI0 port B bit 5, held low by the 68000
    input                clk,
    input                ym2151,   // Enduro Racer sound-board selection

    input                cen_fm,    // 4 MHz, YM2203 (sheet D-2/3, pin 38 OM from 4M)
    input                cen_fm2,   // 2 MHz, YM2151 internal timing
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
    output       [18:0]  pcm_addr,
    output               pcm_cs,
    input        [ 7:0]  pcm_data,
    input                pcm_ok,

    output signed [15:0] fm, opn_l, opn_r,
    output        [ 9:0] psg,
    output signed [15:0] pcm_l,
    output signed [15:0] pcm_r
);
`ifndef NOSOUND
wire [15:0] A;
wire [ 7:0] cpu_dout, ram_dout, fm_dout, pcm_dout, jt03_dout, jt51_dout;
wire        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, jt03_irq_n, jt51_irq_n,
            jt51_csn, jt03_csn;
reg  [ 7:0] cpu_din;
reg         ram_cs, fm_cs, pcmcmd_cs, latch_cs,
            snd_rst, jt03_rst, jt51_rst, int_n;

assign jt51_csn =~(fm_cs &  ym2151);
assign jt03_csn =~(fm_cs & ~ym2151);
assign fm_dout  = ym2151 ? jt51_dout : jt03_dout;
assign rom_addr = A[14:0];
assign latch_rd = latch_cs;

always @(posedge clk) begin
    int_n    <= ym2151 ? jt51_irq_n : jt03_irq_n;
    snd_rst  <= ~snd_rstn;
    jt03_rst <= ~snd_rstn |  ym2151;
    jt51_rst <= ~snd_rstn | ~ym2151;
end

always @(*) begin
    rom_cs   = !mreq_n && rfsh_n && !A[15];
    latch_cs = !iorq_n &&  !rd_n &&  A[ 7: 6]==2'h1;
    if(ym2151) begin
        ram_cs   = !mreq_n && rfsh_n && A[15:11]==5'b11111;
        pcmcmd_cs = !mreq_n && rfsh_n && A[15:11]==5'b11110;
        fm_cs    = !iorq_n && m1_n && A[7:6]==2'b00;
    end else begin
        ram_cs   = !mreq_n && rfsh_n && A[15:12]==4'hc;
        pcmcmd_cs = !mreq_n && rfsh_n && A[15:12]==4'he;
        fm_cs    = !mreq_n && rfsh_n && A[15:12]==4'hd;
    end
end

always @(*) begin
    cpu_din = rom_cs    ? rom_data :
              ram_cs    ? ram_dout :
              fm_cs     ? fm_dout  :
              pcmcmd_cs ? pcm_dout :
              latch_cs  ? latch    : 8'hff;
end

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n      ( snd_rstn    ),
    .clk        ( clk         ),
    .cen        ( cen_fm      ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
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

jt03 u_jt03(
    .rst        ( jt03_rst    ),
    .clk        ( clk         ),
    .cen        ( cen_fm      ),
    .din        ( cpu_dout    ),
    .addr       ( A[0]        ),
    .cs_n       ( jt03_csn    ),
    .wr_n       ( wr_n        ),
    .dout       ( jt03_dout   ),
    .irq_n      ( jt03_irq_n  ),

    .psg_snd    ( psg         ),
    .fm_snd     ( fm          ),
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

jt51 u_jt51(
    .rst        ( jt51_rst    ),
    .clk        ( clk         ),
    .cen        ( cen_fm      ),
    .cen_p1     ( cen_fm2     ),
    .cs_n       ( jt51_csn    ),
    .wr_n       ( wr_n        ),
    .a0         ( A[0]        ),
    .din        ( cpu_dout    ),
    .dout       ( jt51_dout   ),
    .ct1        (             ),
    .ct2        (             ),
    .irq_n      ( jt51_irq_n  ),
    .sample     (             ),
    .left       (             ),
    .right      (             ),
    .xleft      ( opn_l       ),
    .xright     ( opn_r       )
);

// sharrier's PCM is not exactly OutRun's. It is a discrete IC implementation
// Expanding the internal bit width of the channels in jtoutrun_pcm makes it
// compatible. Otherwise, it would clip the sound.
jtoutrun_pcm #(.WD(16)) u_pcm(
    .rst        ( snd_rst     ),
    .clk        ( clk         ),
    .cen        ( ym2151 ? cen_fm : cen_pcm ),

    .cpu_addr   ( A[7:0]      ),
    .cpu_dout   ( cpu_dout    ),
    .cpu_din    ( pcm_dout    ),
    .cpu_rnw    ( wr_n        ),
    .cpu_cs     ( pcmcmd_cs   ),

    .rom_addr   ( pcm_addr    ),
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
assign fm       = 0;
assign psg      = 0;
assign opn_l    = 0;
assign opn_r    = 0;
assign pcm_l    = 0;
assign pcm_r    = 0;
initial rom_cs  = 0;
`endif

endmodule
