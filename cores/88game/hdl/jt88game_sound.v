/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-10-2026 */

module jt88game_sound(
    input                rst,
    input                clk,
    input                cen_fm,
    input                cen_fm2,
    input                cen_640,
    input                snd_irq,
    input        [ 7:0]  snd_latch,

    output       [14:0]  rom_addr,
    output reg           rom_cs,
    input        [ 7:0]  rom_data,
    input                rom_ok,

    output       [17:0]  pcm_addr,
    output               pcm_cs,
    input        [ 7:0]  pcm_data,
    input                pcm_ok,

    output signed [15:0] fm_l, fm_r,
    output signed [ 8:0] pcm,
    output       [ 7:0]  st_dout
);
`ifndef NOSOUND

wire [16:0] pcm_chip_addr;
wire [15:0] cpu_addr;
wire [ 7:0] cpu_dout, ram_dout, fm_dout;
wire        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n;
wire        irq_ack, irq_n, pcm_busyn;
reg  [ 7:0] cpu_din, pcm_msg;
reg         ram_cs, latch_cs, fm_cs, busy_cs, msg_cs, ctrl_cs;
reg         pcm_bank, pcm_rstn, pcm_start_n;
reg         mem_acc, pcm_rst;

assign rom_addr = cpu_addr[14:0];
assign pcm_addr = { pcm_bank, pcm_chip_addr };
assign irq_ack  = !m1_n && !iorq_n;
assign st_dout  = { pcm_bank, pcm_rstn, pcm_start_n, pcm_busyn,
                    cpu_addr[15:12] };

always @* begin
    mem_acc  = !mreq_n && rfsh_n;
    rom_cs   = mem_acc && !cpu_addr[15] && !rd_n;
    ram_cs   = mem_acc && cpu_addr[15:12]==4'h8;
    msg_cs   = mem_acc && cpu_addr[15:12]==4'h9;
    latch_cs = mem_acc && cpu_addr[15:12]==4'ha;
    fm_cs    = mem_acc && cpu_addr[15:12]==4'hc;
    busy_cs  = mem_acc && cpu_addr[15:12]==4'hd;
    ctrl_cs  = mem_acc && cpu_addr[15:12]==4'he;
end

always @* begin
    cpu_din = rom_cs   ? rom_data                :
              ram_cs   ? ram_dout                :
              latch_cs ? snd_latch               :
              fm_cs    ? fm_dout                 :
              busy_cs  ? {7'h7f, pcm_busyn}      : 8'hff;
end

always @(posedge clk) begin
    pcm_rst <= rst | ~pcm_rstn;
end

always @(posedge clk) begin
    if (rst) begin
        pcm_msg     <= 0;
        pcm_bank    <= 0;
        pcm_rstn    <= 0;
        pcm_start_n <= 1;
    end else begin
        if (msg_cs && !wr_n) pcm_msg <= cpu_dout;
        if (ctrl_cs && !wr_n) begin
            pcm_bank    <=  cpu_dout[2];
            pcm_rstn    <=  cpu_dout[1];
            pcm_start_n <= ~cpu_dout[0];
        end
    end
end

jtframe_edge #(.QSET(0)) u_irq(
    .rst    ( rst     ),
    .clk    ( clk     ),
    .edgeof ( snd_irq ),
    .clr    ( irq_ack ),
    .q      ( irq_n   )
);

jt51 u_fm(
    .rst    ( rst         ),
    .clk    ( clk         ),
    .cen    ( cen_fm      ),
    .cen_p1 ( cen_fm2     ),
    .cs_n   ( ~fm_cs      ),
    .wr_n   ( wr_n        ),
    .a0     ( cpu_addr[0] ),
    .din    ( cpu_dout    ),
    .dout   ( fm_dout     ),
    .ct1    (             ),
    .ct2    (             ),
    .irq_n  (             ),
    .sample (             ),
    .left   (             ),
    .right  (             ),
    .xleft  ( fm_l        ),
    .xright ( fm_r        )
);

jt7759 u_pcm(
    .rst      ( pcm_rst       ),
    .clk      ( clk           ),
    .cen      ( cen_640       ),
    .stn      ( pcm_start_n   ),
    .cs       ( 1'b1          ),
    .mdn      ( 1'b1          ),
    .busyn    ( pcm_busyn     ),
    .wrn      ( 1'b1          ),
    .din      ( pcm_msg       ),
    .drqn     (               ),
    .rom_cs   ( pcm_cs        ),
    .rom_addr ( pcm_chip_addr ),
    .rom_data ( pcm_data      ),
    .rom_ok   ( pcm_ok        ),
    .sound    ( pcm           )
);

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n    ( ~rst     ),
    .clk      ( clk      ),
    .cen      ( cen_fm   ),
    .cpu_cen  (          ),
    .int_n    ( irq_n    ),
    .nmi_n    ( 1'b1     ),
    .busrq_n  ( 1'b1     ),
    .m1_n     ( m1_n     ),
    .mreq_n   ( mreq_n   ),
    .iorq_n   ( iorq_n   ),
    .rd_n     ( rd_n     ),
    .wr_n     ( wr_n     ),
    .rfsh_n   ( rfsh_n   ),
    .halt_n   (          ),
    .busak_n  (          ),
    .A        ( cpu_addr ),
    .cpu_din  ( cpu_din  ),
    .cpu_dout ( cpu_dout ),
    .ram_dout ( ram_dout ),
    .ram_cs   ( ram_cs   ),
    .rom_cs   ( rom_cs   ),
    .rom_ok   ( rom_ok   )
);
`else
assign rom_addr = 0;
assign pcm_addr = 0;
assign pcm_cs   = 0;
assign { fm_l, fm_r, pcm, st_dout } = 0;
initial rom_cs  = 0;
`endif
endmodule
