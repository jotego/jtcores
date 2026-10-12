/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtroller_sound(
    input             rst, clk, cen_fm, cen_pcm,
    input             snd_irq,
    input             main_cs, main_we, main_a0,
    input      [ 7:0] main_dout,
    output     [ 7:0] main_din,

    output     [14:0] rom_addr,
    output reg        rom_cs,
    input      [ 7:0] rom_data,
    input             rom_ok,

    output     [18:0] pcma_addr, pcmb_addr, pcmc_addr, pcmd_addr,
    output            pcma_cs, pcmb_cs, pcmc_cs, pcmd_cs,
    input      [ 7:0] pcma_data, pcmb_data, pcmc_data, pcmd_data,
    input             pcma_ok, pcmb_ok, pcmc_ok, pcmd_ok,

    output signed [15:0] fm, pcm_l, pcm_r,
    input      [ 5:0] snd_en
);
`ifndef NOSOUND

wire [20:0] rawa_addr, rawb_addr, rawc_addr, rawd_addr;
wire [15:0] addr;
wire [ 7:0] cpu_dout, ram_dout, fm_dout, pcm_dout;
wire        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n;
wire        mem_acc, irq_ack, irq_n, nmi_n, sh1, arm_nmi;
wire        nmi_clr;
reg  [ 7:0] cpu_din;
reg         ram_cs, fm_cs, pcm_cs;
reg  [ 5:0] sh1_count;
reg  [ 2:0] nmi_block;

assign rom_addr  = addr[14:0];
assign pcma_addr = rawa_addr[18:0];
assign pcmb_addr = rawb_addr[18:0];
assign pcmc_addr = rawc_addr[18:0];
assign pcmd_addr = rawd_addr[18:0];
assign mem_acc   = !mreq_n && rfsh_n;
assign irq_ack   = !m1_n && !iorq_n;
assign arm_nmi   = mem_acc && !wr_n && addr==16'hfc00;
assign sh1       = sh1_count[5:4]==2'b00;
assign nmi_clr   = arm_nmi || |nmi_block;

// SH1 rises once every 64 chip clocks, even while PCM ROM access stalls.
// cen_fm has the same nominal rate as cen_pcm without its SDRAM gate.
always @(posedge clk) begin
    if (rst) begin
        sh1_count <= 0;
        nmi_block <= 0;
    end else begin
        if (cen_fm) sh1_count <= sh1_count+1'd1;
        // The sound board keeps NMI clear for four Z80 clocks after FC00.
        // This lets the Z80 sample the released line before the next SH1 edge.
        if (arm_nmi) nmi_block <= 3'd4;
        else if (cen_fm && |nmi_block) nmi_block <= nmi_block-1'd1;
    end
end

always @* begin
    rom_cs = mem_acc && !addr[15] && !rd_n;
    ram_cs = mem_acc && addr[15:11]==5'b10000;
    pcm_cs = mem_acc && addr[15:6]==10'b1010_0000_00;
    fm_cs  = mem_acc && addr[15:1]==15'h6000;
end

always @* begin
    cpu_din = rom_cs ? rom_data :
              ram_cs ? ram_dout :
              pcm_cs ? pcm_dout :
              fm_cs  ? fm_dout  : 8'hff;
end

jtframe_edge #(.QSET(0)) u_irq(
    .rst    ( rst     ),
    .clk    ( clk     ),
    .edgeof ( snd_irq ),
    .clr    ( irq_ack ),
    .q      ( irq_n   )
);

jtframe_edge #(.QSET(0),.ATRST(0)) u_nmi(
    .rst    ( rst     ),
    .clk    ( clk     ),
    .edgeof ( sh1     ),
    .clr    ( nmi_clr ),
    .q      ( nmi_n   )
);

jtopl2 u_fm(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen_fm    ),
    .din    ( cpu_dout  ),
    .addr   ( addr[0]   ),
    .cs_n   ( ~fm_cs    ),
    .wr_n   ( wr_n      ),
    .dout   ( fm_dout   ),
    .irq_n  (           ),
    .snd    ( fm        ),
    .sample (           )
);

jt053260 u_pcm(
    .rst       ( rst        ),
    .clk       ( clk        ),
    .cen       ( cen_pcm    ),
    .ma0       ( main_a0    ),
    .mrdnw     ( ~main_we   ),
    .mcs       ( main_cs    ),
    .mdout     ( main_dout  ),
    .mdin      ( main_din   ),
    .addr      ( addr[5:0]  ),
    .rd_n      ( rd_n       ),
    .wr_n      ( wr_n       ),
    .cs        ( pcm_cs     ),
    .dout      ( pcm_dout   ),
    .din       ( cpu_dout   ),
    .roma_addr ( rawa_addr  ),
    .roma_data ( pcma_data  ),
    .roma_cs   ( pcma_cs    ),
    .romb_addr ( rawb_addr  ),
    .romb_data ( pcmb_data  ),
    .romb_cs   ( pcmb_cs    ),
    .romc_addr ( rawc_addr  ),
    .romc_data ( pcmc_data  ),
    .romc_cs   ( pcmc_cs    ),
    .romd_addr ( rawd_addr  ),
    .romd_data ( pcmd_data  ),
    .romd_cs   ( pcmd_cs    ),
    .aux_l     ( 16'sd0     ),
    .aux_r     ( 16'sd0     ),
    .snd_l     ( pcm_l      ),
    .snd_r     ( pcm_r      ),
    .sample    (            ),
    .tim2      (            ),
    .ch_en     ( snd_en[5:1] )
);

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n    ( ~rst      ),
    .clk      ( clk       ),
    .cen      ( cen_fm    ),
    .cpu_cen  (           ),
    .int_n    ( irq_n     ),
    .nmi_n    ( nmi_n     ),
    .busrq_n  ( 1'b1      ),
    .m1_n     ( m1_n      ),
    .mreq_n   ( mreq_n    ),
    .iorq_n   ( iorq_n    ),
    .rd_n     ( rd_n      ),
    .wr_n     ( wr_n      ),
    .rfsh_n   ( rfsh_n    ),
    .halt_n   (           ),
    .busak_n  (           ),
    .A        ( addr      ),
    .cpu_din  ( cpu_din   ),
    .cpu_dout ( cpu_dout  ),
    .ram_dout ( ram_dout  ),
    .ram_cs   ( ram_cs    ),
    .rom_cs   ( rom_cs    ),
    .rom_ok   ( rom_ok    )
);
`else
assign {main_din,rom_addr,pcma_addr,pcmb_addr,pcmc_addr,pcmd_addr,
        pcma_cs,pcmb_cs,pcmc_cs,pcmd_cs,fm,pcm_l,pcm_r}=0;
initial rom_cs=0;
`endif
endmodule
