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
    output signed [15:0] snd,
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
jt12_top #(
    .use_lfo   ( 1 ),
    .use_ssg   ( 1 ),
    .num_ch    ( 6 ),
    .use_pcm   ( 0 ),
    .use_adpcm ( 0 ),
    .mask_div  ( 0 )
) u_fm(
    .rst          ( rst      ),
    .clk          ( clk      ),
    .cen          ( fm_cen   ),
    .din          ( cpu_dout ),
    .addr         ( a[1:0]   ),
    .cs_n         ( ~fm_cs   ),
    .wr_n         ( wr_n     ),
    .dout         ( fm_dout  ),
    .irq_n        ( int_n    ),
    .en_hifi_pcm  ( 1'b0     ),
    .adpcma_addr  (          ),
    .adpcma_bank  (          ),
    .adpcma_roe_n (          ),
    .adpcma_data  ( 8'd0     ),
    .adpcmb_addr  (          ),
    .adpcmb_data  ( 8'd0     ),
    .adpcmb_roe_n (          ),
    .IOA_in       ( 8'hff    ),
    .IOB_in       ( 8'hff    ),
    .IOA_out      (          ),
    .IOB_out      ( bank     ),
    .IOA_oe       (          ),
    .IOB_oe       (          ),
    .psg_A        (          ),
    .psg_B        (          ),
    .psg_C        (          ),
    .fm_snd_left  (          ),
    .fm_snd_right (          ),
    .adpcmA_l     (          ),
    .adpcmA_r     (          ),
    .adpcmB_l     (          ),
    .adpcmB_r     (          ),
    .psg_snd      (          ),
    .snd_right    (          ),
    .snd_left     ( snd      ),
    .snd_sample   ( sample   ),
    .ch_enable    ( 6'h3f    ),
    .debug_bus    ( 8'd0     ),
    .debug_view   (          )
);

endmodule
