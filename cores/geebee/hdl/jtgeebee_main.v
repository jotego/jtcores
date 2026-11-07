/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 06-11-2026 */

module jtgeebee_main(
    input             clk,
    input             rst,
    input             cen_cpu,
    input             vblank,
    input      [7:0]  sw0,
    input      [7:0]  sw1,
    input      [7:0]  dsw,
    input      [7:0]  paddle,
    output     [11:0] maincpu_addr,
    input      [7:0]  maincpu_data,
    output     [9:0]  gfx_cpu_addr,
    output            gfx_cpu_rd,
    input      [7:0]  gfx1_data,
    output     [9:0]  vram_addr,
    output            vram_we,
    output     [7:0]  vram_din,
    input      [7:0]  vram_dout,
    output     [7:0]  workram_addr,
    output            workram_we,
    output     [7:0]  workram_din,
    input      [7:0]  workram_dout,
    output            snd_wr,
    output     [7:0]  snd_din,
    output            bgw,
    output            ball_on,
    output            flip,
    output reg [7:0]  ball_x,
    output reg [7:0]  ball_y
);

wire [15:0] addr;
wire [7:0]  dout;
wire m1_n, mreq_n, iorq_n, rd_n, wr_n, halt_n;
wire bus_rd = !rd_n && (!mreq_n || !iorq_n);
wire bus_wr = !wr_n && (!mreq_n || !iorq_n);
wire [2:0] block = addr[14:12];
wire rom2_sel = block == 3'd0;
wire vram_sel = block == 3'd2;
wire cgrom_sel = block == 3'd3;
wire ram_sel = block == 3'd4;
wire in_sel = block == 3'd5;
wire out6_sel = block == 3'd6;
wire out7_sel = block == 3'd7;
wire sw_read0 = in_sel && addr[1:0] == 2'd0;
wire sw_read1 = in_sel && addr[1:0] == 2'd1;
wire sw_read2 = in_sel && addr[1:0] == 2'd2;
wire vol_read = in_sel && addr[1:0] == 2'd3;
wire bhd_wr = out6_sel && addr[1:0] == 2'd0;
wire bvd_wr = out6_sel && addr[1:0] == 2'd1;
wire sound_wr = out6_sel && addr[1:0] == 2'd3;
wire int_ack = !m1_n && !iorq_n;
reg [7:0] din;
reg [7:0] latch;
reg vblank_d;
reg irq;

assign maincpu_addr = addr[11:0];
assign gfx_cpu_addr = addr[9:0];
assign gfx_cpu_rd   = bus_rd && cgrom_sel;
assign vram_addr    = addr[9:0];
assign vram_we      = cen_cpu && bus_wr && vram_sel;
assign vram_din     = dout;
assign workram_addr = addr[7:0];
assign workram_we   = cen_cpu && bus_wr && ram_sel;
assign workram_din  = dout;
assign snd_wr       = cen_cpu && bus_wr && sound_wr;
assign snd_din      = dout;
assign bgw          = latch[5];
assign ball_on      = latch[6];
assign flip         = latch[7];

always @* begin
    din = 8'hff;
    if (int_ack) begin
        din = 8'hcf;
    end else if (bus_rd) begin
        if (rom2_sel) din = maincpu_data;
        if (vram_sel) din = vram_dout;
        if (cgrom_sel) din = gfx1_data;
        if (ram_sel) din = workram_dout;
        if (sw_read0) din = sw0;
        if (sw_read1) din = sw1;
        if (sw_read2) din = dsw;
        if (vol_read) din = paddle;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        latch    <= 0;
        ball_x   <= 0;
        ball_y   <= 0;
        vblank_d <= 0;
        irq      <= 0;
    end else begin
        vblank_d <= vblank;
        if (vblank && !vblank_d) irq <= 1;
        if (int_ack) irq <= 0;
        if (cen_cpu && bus_wr) begin
            if (bhd_wr) ball_x <= dout;
            if (bvd_wr) ball_y <= dout;
            if (out7_sel)
                latch[addr[2:0]] <= dout[0];
        end
    end
end

`ifdef VERILATOR
T80s u_cpu(
`elsif IVERILOG
T80s u_cpu(
`elsif JTFRAME_VZ80
T80s u_cpu(
`else
T80s #(
    .Mode   ( 2 )
) u_cpu(
`endif
    .RESET_n( ~rst    ),
    .CLK    ( clk     ),
    .CEN    ( cen_cpu ),
    .WAIT_n ( 1'b1    ),
    .INT_n  ( ~irq    ),
    .NMI_n  ( 1'b1    ),
    .BUSRQ_n( 1'b1    ),
    .OUT0   ( 1'b0    ),
    .DI     ( din     ),
    .M1_n   ( m1_n    ),
    .MREQ_n ( mreq_n  ),
    .IORQ_n ( iorq_n  ),
    .RD_n   ( rd_n    ),
    .WR_n   ( wr_n    ),
    .RFSH_n (         ),
    .HALT_n ( halt_n  ),
    .BUSAK_n(         ),
    .A      ( addr    ),
    .DOUT   ( dout    )
);

endmodule
