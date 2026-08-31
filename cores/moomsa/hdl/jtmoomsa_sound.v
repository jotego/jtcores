/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_sound(
    input                   clk,
    input                   rst,
    input                   cen_8,
    input                   cen_pcm,
    input                   cen_4,
    input                   cen_2,
    output      [17:0]      rom_addr,
    output                  rom_cs,
    input       [7:0]       rom_data,
    input                   rom_ok,
    output      [20:0]      pcm_addr,
    output                  pcm_cs,
    input       [7:0]       pcm_data,
    input                   pcm_ok,
    input       [3:0]       main_addr,
    input       [7:0]       main_dout,
    input                   pair_we,
    input                   sdon,
    input       [5:0]       snd_en,
    output      [7:0]       pair_dout,
    output signed [15:0]    audio_l,
    output signed [15:0]    audio_r,
    output                  sample
);

wire [15:0] A;
wire [7:0] cpu_dout, cpu_din, ram_dout, fm_dout, pcm_dout, latch_dout;
wire [23:0] sample_addr;
wire sample_req;
wire sample_ack;
wire fm_irq_n, latch_int_n, bank_cs, latch_cs, bank_write, nmi_clr;
wire signed [15:0] fm_l, fm_r;
wire signed [15:0] pcm_l, pcm_r;
wire signed [15:0] mix_l, mix_r;
wire                mix_peak_l, mix_peak_r;
wire m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, int_n, nmi_n;
wire cpu_cen;
wire ram_cs, fm_cs, pcm_reg_cs;
wire [3:0] rom_hi;
wire sample_accept;
reg [3:0] bank;
reg nmi_clrr;
reg pcm_hold;
reg [20:0] pcm_addr_hold;
/* C14 Z80 status is retained explicitly for diagnostics. */
/* verilator lint_off UNUSEDSIGNAL */
wire sound_cpu_halt_n;
wire sound_cpu_busak_n;
wire fm_ct1;
wire fm_ct2;
wire fm_sample;
wire signed [15:0] fm_left;
wire signed [15:0] fm_right;
wire               mix_peak_l_diag = mix_peak_l;
wire               mix_peak_r_diag = mix_peak_r;
wire pcm_cpu_dout_valid;
wire [8:0] pcm_sequence_cycle;
wire [2:0] pcm_active_channel;
wire [7:0] pcm_active_flags;
/* verilator lint_on UNUSEDSIGNAL */

jtmoomsa_sound_pal u_pal(
    .addr(A), .mreq_n(mreq_n), .rfsh_n(rfsh_n), .rd_n(rd_n),
    .rom_cs(rom_cs), .ram_cs(ram_cs),
    .fm_cs(fm_cs), .pcm_cs(pcm_reg_cs), .bank_cs(bank_cs),
    .latch_cs(latch_cs)
);

jtmoomsa_sound_bank_mux u_bank_mux(
    .snd_a14(A[14]), .snd_a15(A[15]), .sbank(bank), .muxed(rom_hi)
);

assign rom_addr = {rom_hi,A[13:0]};
assign bank_write = bank_cs && !wr_n;

assign cpu_din = rom_cs ? rom_data : ram_cs ? ram_dout :
                 fm_cs ? fm_dout : pcm_reg_cs ? pcm_dout :
                 latch_dout;
assign sample_ack = pcm_hold && pcm_ok;
assign sample_accept = !pcm_hold;
assign pcm_cs = pcm_hold;
assign pcm_addr = pcm_addr_hold;

always @(posedge clk) begin
    if( rst ) begin
        pcm_hold <= 1'b0;
        pcm_addr_hold <= 21'd0;
    end else if( !pcm_hold && sample_req ) begin
        pcm_hold <= 1'b1;
        pcm_addr_hold <= sample_addr[20:0];
    end else if( pcm_hold && pcm_ok ) begin
        pcm_hold <= 1'b0;
    end
end

jtframe_sysz80 #(.RAM_AW(13),.CLR_INT(1)) u_cpu(
    .rst_n(~rst), .clk(clk), .cen(cen_8), .cpu_cen(cpu_cen),
    .int_n(int_n), .nmi_n(nmi_n), .busrq_n(1'b1),
    .m1_n(m1_n), .mreq_n(mreq_n), .iorq_n(iorq_n),
    .rd_n(rd_n), .wr_n(wr_n), .rfsh_n(rfsh_n),
    .halt_n(sound_cpu_halt_n), .busak_n(sound_cpu_busak_n), .A(A), .cpu_din(cpu_din),
    .cpu_dout(cpu_dout), .ram_dout(ram_dout),
    .ram_cs(ram_cs), .rom_cs(rom_cs), .rom_ok(rom_ok)
);

jt51 u_fm(
    .rst(rst), .clk(clk), .cen(cen_4), .cen_p1(cen_2),
    .cs_n(~fm_cs), .wr_n(wr_n), .a0(A[0]), .din(cpu_dout),
    .dout(fm_dout), .ct1(fm_ct1), .ct2(fm_ct2), .irq_n(fm_irq_n),
    .sample(fm_sample), .left(fm_left), .right(fm_right), .xleft(fm_l), .xright(fm_r)
);

always @(posedge clk) begin
    if( rst ) begin
        bank <= 4'd0;
        nmi_clrr <= 1'b0;
    end else if( bank_write ) begin
        bank <= cpu_dout[3:0];
        nmi_clrr <= cpu_dout[4];
    end
end

jtframe_edge #(.QSET(0)) u_nmi(
    .rst(rst), .clk(clk), .edgeof(~fm_irq_n), .clr(nmi_clr), .q(nmi_n)
);

jtmoomsa_054539 u_pcm(
    .clk(clk), .cen(cen_pcm), .rst(rst),
    .cpu_cs(pcm_reg_cs), .cpu_wr(!wr_n), .cpu_rd(!rd_n),
    .cpu_addr(A[9:0]), .cpu_din(cpu_dout), .cpu_dout(pcm_dout),
    .cpu_dout_valid(pcm_cpu_dout_valid), .sample_req(sample_req), .sample_accept(sample_accept), .sample_addr(sample_addr),
    .sample_data({pcm_data,pcm_data}), .sample_ack(sample_ack),
    .audio_l(pcm_l), .audio_r(pcm_r), .audio_valid(sample),
    .sequence_cycle(pcm_sequence_cycle), .active_channel(pcm_active_channel), .active_flags(pcm_active_flags)
);

// The PCB presents the YM2151 and K054539 at the common digital mixer/DAC
// boundary. Keep the sum signed and saturating so full-scale signals cannot
// wrap before the MiSTer sound boundary. snd_en[0] is the FM channel; any
// enabled PCM channel enables the PCM bus.
jtframe_limsum #(.WI(16),.WO(16),.K(2)) u_mix_l(
    .rst(rst), .clk(clk), .cen(cen_pcm),
    .parts({pcm_l, fm_l}),
    .en({|snd_en[5:1], snd_en[0]}),
    .sum(mix_l), .peak(mix_peak_l)
);

jtframe_limsum #(.WI(16),.WO(16),.K(2)) u_mix_r(
    .rst(rst), .clk(clk), .cen(cen_pcm),
    .parts({pcm_r, fm_r}),
    .en({|snd_en[5:1], snd_en[0]}),
    .sum(mix_r), .peak(mix_peak_r)
);

assign audio_l = mix_l;
assign audio_r = mix_r;

assign int_n = latch_int_n;
// D7 Q4 is the active-low /NMI_CLR net.  G6B uses that net on its
// active-low preset input, so a zero in the latched bit clears the NMI.
assign nmi_clr = ~nmi_clrr;

jt054321 u_054321(
    .rst(rst), .clk(clk),
    .maddr(main_addr), .mdout(main_dout), .mdin(pair_dout), .mwe(pair_we),
    .saddr(A[1:0]), .sdout(cpu_dout), .sdin(latch_dout),
    .swe(latch_cs && !wr_n), .snd_on(sdon), .siorq_n(iorq_n),
    .int_n(latch_int_n)
);

endmodule
