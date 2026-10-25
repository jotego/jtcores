/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-10-2026 */

module jtsvolle_snd(
    input                rst, clk, snd_cen, fm_cen, fm2_cen, pcm_cen,
    input      [7:0]     latch_data,
    input                latch_wr,
    output reg           pending,
    output     [15:0]    rom_addr,
    output               rom_cs,
    input      [7:0]     rom_data,
    input                rom_ok,
    output     [10:0]    ram_addr,
    output     [7:0]     ram_din,
    output               ram_we,
    input      [7:0]     ram_data,
    output     [17:0]    pcm_addr,
    output               pcm_cs,
    input      [7:0]     pcm_data,
    input                pcm_ok,
    input      [5:0]     snd_en,
    output signed [15:0] sound,
    output               sample
);

wire [15:0] a;
wire [7:0] dout, fm_data;
wire mreq_n, iorq_n, m1_n, rd_n, wr_n, rfsh_n, cpu_cen;
wire fm_irq_n, fm_sample;
wire signed [15:0] fm_l, fm_r;
wire signed [8:0] pcm_sound;
wire mem_cs = !mreq_n && rfsh_n;
wire ram_cs = mem_cs && a >= 16'hf800;
wire fm_cs = mem_cs && a[15:1]==15'h7800;
wire latch_rd = mem_cs && !rd_n && a==16'hf200;
wire control_wr = mem_cs && !wr_n && a==16'hf400;
wire start_wr = mem_cs && !wr_n && a==16'hf600;
wire [7:0] din = rom_cs ? rom_data : ram_cs ? ram_data :
                 fm_cs ? fm_data : latch_rd ? latch_data : 8'hff;
reg pcm_bank, pcm_reset_n, pcm_start_n, start_seen;
reg [7:0] pcm_command;
wire [16:0] pcm_rom_addr;
wire signed [16:0] fm_mix = ($signed({fm_l[15],fm_l}) +
                            $signed({fm_r[15],fm_r})) >>> 1;
wire signed [16:0] pcm_mix = $signed({{8{pcm_sound[8]}},pcm_sound}) <<< 6;
wire signed [17:0] mix = (snd_en[0] ? {fm_mix[16],fm_mix} : 18'd0) +
                        (snd_en[1] ? {pcm_mix[16],pcm_mix} : 18'd0);

assign rom_addr = a;
assign rom_cs = mem_cs && a < 16'hf000 && !rd_n;
assign ram_addr = a[10:0];
assign ram_din = dout;
assign ram_we = ram_cs && !wr_n;
assign pcm_addr = {pcm_bank,pcm_rom_addr};
assign sound = mix > 18'sd32767 ? 16'sh7fff :
               mix < -18'sd32768 ? 16'sh8000 : mix[15:0];
assign sample = fm_sample;

always @(posedge clk) begin
    if(rst) begin
        pending <= 0;
        pcm_bank <= 0;
        pcm_reset_n <= 0;
        pcm_start_n <= 1;
        pcm_command <= 0;
        start_seen <= 0;
    end else begin
        if(latch_rd) pending <= 0;
        if(latch_wr) pending <= 1;
        if(!start_wr) start_seen <= 0;
        pcm_start_n <= 1;
        if(start_wr && !start_seen) begin
            start_seen <= 1;
            pcm_command <= dout;
            pcm_start_n <= 0;
        end
        if(control_wr) begin
            pcm_bank <= dout[0];
            pcm_reset_n <= dout[7];
        end
    end
end

`ifndef NOSOUND
jtframe_z80_devwait u_cpu(
    .rst_n      ( !rst           ),
    .clk        ( clk            ),
    .cen        ( snd_cen        ),
    .cpu_cen    ( cpu_cen        ),
    .int_n      ( fm_irq_n && !pending ),
    .nmi_n      ( 1'b1           ),
    .busrq_n    ( 1'b1           ),
    .m1_n       ( m1_n           ),
    .mreq_n     ( mreq_n         ),
    .iorq_n     ( iorq_n         ),
    .rd_n       ( rd_n           ),
    .wr_n       ( wr_n           ),
    .rfsh_n     ( rfsh_n         ),
    .halt_n     (                ),
    .busak_n    (                ),
    .A          ( a              ),
    .din        ( din            ),
    .dout       ( dout           ),
    .rom_cs     ( rom_cs         ),
    .rom_ok     ( rom_ok         ),
    .dev_busy   ( 1'b0           )
);

jt51 u_fm(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .cen        ( fm_cen         ),
    .cen_p1     ( fm2_cen        ),
    .cs_n       ( !fm_cs         ),
    .wr_n       ( wr_n           ),
    .a0         ( a[0]           ),
    .din        ( dout           ),
    .dout       ( fm_data        ),
    .ct1        (                ),
    .ct2        (                ),
    .irq_n      ( fm_irq_n       ),
    .sample     ( fm_sample      ),
    .left       (                ),
    .right      (                ),
    .xleft      ( fm_l           ),
    .xright     ( fm_r           )
);

jt7759 u_pcm(
    .rst        ( rst || !pcm_reset_n ),
    .clk        ( clk            ),
    .cen        ( pcm_cen        ),
    .stn        ( pcm_start_n    ),
    .cs         ( 1'b1           ),
    .mdn        ( 1'b1           ),
    .busyn      (                ),
    .wrn        ( 1'b1           ),
    .din        ( pcm_command    ),
    .drqn       (                ),
    .rom_cs     ( pcm_cs         ),
    .rom_addr   ( pcm_rom_addr   ),
    .rom_data   ( pcm_addr[17:16]==2'b11 ? 8'd0 : pcm_data ),
    .rom_ok     ( pcm_ok         ),
    .sound      ( pcm_sound      )
);
`else
assign a = 0;
assign dout = 0;
assign mreq_n = 1;
assign iorq_n = 1;
assign m1_n = 1;
assign rd_n = 1;
assign wr_n = 1;
assign rfsh_n = 1;
assign fm_l = 0;
assign fm_r = 0;
assign fm_data = 0;
assign fm_irq_n = 1;
assign fm_sample = 0;
assign pcm_sound = 0;
assign pcm_cs = 0;
assign pcm_rom_addr = 0;
`endif

endmodule
