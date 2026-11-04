/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 01-11-2026 */

module jtttnose_snd(
    input rst,
    input clk,
    input snd_cen,
    input fm_cen,
    input [7:0] snd_latch,
    input snd_wr,
    output reg snd_pending,
    output [16:0] rom_addr,
    output rom_cs,
    input [7:0] rom_data,
    input rom_ok,
    output [10:0] ram_addr,
    output [7:0] ram_din,
    output ram_we,
    input [7:0] ram_data,
    output [16:0] pcm_addr,
    output pcm_cs,
    input [7:0] pcm_data,
    input pcm_ok,
    output [12:0] rhythm_addr,
    input [7:0] rhythm_data,
    output signed [15:0] snd_left, snd_right,
    output sample
);
wire [15:0] a;
wire [7:0] cpu_dout,fm_dout,bank;
wire mreq_n,iorq_n,rd_n,wr_n,m1_n,rfsh_n,int_n;
wire mem_acc=!mreq_n && rfsh_n;
wire io_acc=!iorq_n && m1_n;
wire ram_cs=mem_acc && a[15:11]==5'b01111;
wire latch_cs=io_acc && a[7:0]==8'h07;
wire fm_cs=io_acc && a[7:2]==6'd2;
wire [7:0] cpu_din=ram_cs ? ram_data : rom_cs ? rom_data : latch_cs ? snd_latch : 8'hff;
assign rom_cs=mem_acc && !ram_cs;
assign rom_addr=a[15] ? {1'b1,bank[0],a[14:0]} : {2'd0,a[14:0]};
assign ram_addr=a[10:0];
assign ram_din=cpu_dout;
assign ram_we=ram_cs && !wr_n;
always @(posedge clk) begin
    if(rst) snd_pending<=0;
    else begin
        if(latch_cs && !wr_n) snd_pending<=0;
        if(snd_wr) snd_pending<=1;
    end
end
jtframe_z80_devwait u_cpu(
    .rst_n    ( ~rst         ),
    .clk      ( clk          ),
    .cen      ( snd_cen      ),
    .cpu_cen  (              ),
    .int_n    ( int_n        ),
    .nmi_n    ( ~snd_pending ),
    .busrq_n  ( 1'b1         ),
    .m1_n     ( m1_n         ),
    .mreq_n   ( mreq_n       ),
    .iorq_n   ( iorq_n       ),
    .rd_n     ( rd_n         ),
    .wr_n     ( wr_n         ),
    .rfsh_n   ( rfsh_n       ),
    .halt_n   (              ),
    .busak_n  (              ),
    .A        ( a            ),
    .din      ( cpu_din      ),
    .dout     ( cpu_dout     ),
    .rom_cs   ( rom_cs       ),
    .rom_ok   ( rom_ok       ),
    .dev_busy ( 1'b0         )
);
wire [23:0] adpcm_addr;
wire adpcm_cs,adpcm_we;
wire [7:0] adpcm_din;
wire signed [15:0] digital_left,digital_right;
wire [9:0] psg;
wire pcm_hole=|adpcm_addr[23:17];
wire signed [20:0] mix_left={{5{digital_left[15]}},digital_left}+{6'd0,psg,5'd0};
wire signed [20:0] mix_right={{5{digital_right[15]}},digital_right}+{6'd0,psg,5'd0};
assign pcm_addr=adpcm_addr[16:0];
assign pcm_cs=adpcm_cs && !adpcm_we && !pcm_hole;
assign snd_left=mix_left>32767 ? 16'sh7fff : mix_left< -32768 ? 16'sh8000 : mix_left[15:0];
assign snd_right=mix_right>32767 ? 16'sh7fff : mix_right< -32768 ? 16'sh8000 : mix_right[15:0];

jt08 u_fm(
    .rst          ( rst                            ),
    .clk          ( clk                            ),
    .cen          ( fm_cen                         ),
    .din          ( cpu_dout                       ),
    .addr         ( a[1:0]                         ),
    .cs_n         ( ~fm_cs                         ),
    .wr_n         ( wr_n                           ),
    .rd_n         ( 1'b1                           ),
    .dout         ( fm_dout                        ),
    .irq_n        ( int_n                          ),
    .IOA_in       ( 8'hff                          ),
    .IOB_in       ( 8'hff                          ),
    .IOA_out      (                                ),
    .IOB_out      ( bank                           ),
    .IOA_oe       (                                ),
    .IOB_oe       (                                ),
    .psg_A        (                                ),
    .psg_B        (                                ),
    .psg_C        (                                ),
    .psg_snd      ( psg                            ),
    .fm_left      (                                ),
    .fm_right     (                                ),
    .rhythm_addr  ( rhythm_addr                    ),
    .rhythm_cs    (                                ),
    .rhythm_data  ( rhythm_data                    ),
    .rhythm_left  (                                ),
    .rhythm_right (                                ),
    .adpcm_addr   ( adpcm_addr                     ),
    .adpcm_cs     ( adpcm_cs                       ),
    .adpcm_we     ( adpcm_we                       ),
    .adpcm_din    ( adpcm_din                      ),
    .adpcm_data   ( pcm_hole ? 8'hff : pcm_data    ),
    .adpcm_ok     ( adpcm_we || pcm_hole || pcm_ok ),
    .adpcm_left   (                                ),
    .adpcm_right  (                                ),
    .snd_left     ( digital_left                   ),
    .snd_right    ( digital_right                  ),
    .snd_sample   ( sample                         )
);

`ifdef TTNOSE_SOUND_TRACE
reg trace_wr_l;
integer trace_cycle=0;
integer trace_file;
initial trace_file=$fopen("ym2608_bus.csv","w");
always @(posedge clk) begin
    trace_wr_l<=fm_cs && !wr_n;
    if(rst) trace_cycle<=0;
    else if(fm_cen) trace_cycle<=trace_cycle+1;
    if(fm_cs && !wr_n && !trace_wr_l) begin
        $fwrite(trace_file,"%0d,%0d,%0d\n",trace_cycle,a[1:0],cpu_dout);
        $fflush(trace_file);
    end
end
`endif

endmodule
