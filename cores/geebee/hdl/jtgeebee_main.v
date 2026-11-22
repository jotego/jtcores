/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 06-11-2026 */

module jtgeebee_main(
    input             clk,
    input             rst,
    input             cen_cpu,
    input             pxl_cen,
    input      [8:0]  h,
    input      [8:0]  v,
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
wire ram_cycle = ram_sel && !mreq_n && (!rd_n || !wr_n);
wire video_cycle = (vram_sel || cgrom_sel) && !mreq_n && (!rd_n || !wr_n);
// Sheet 8: 4F/4E feed 3V READY logic; 2U receives RAM select.
// 8224 READY feeds 8080 1F pin23; WAIT leaves 1F pin24.
wire ready_n = (!ram_cycle || ram_waited) &&
               !(video_cycle && ready_h_nq && ready_v_q);
reg [7:0] din;
reg [7:0] latch;
reg vblank_d;
reg irq;
reg ram_waited;
reg ready_h_nq;
reg ready_v_q;

assign maincpu_addr = addr[11:0];
assign gfx_cpu_addr = addr[9:0];
assign gfx_cpu_rd   = bus_rd && cgrom_sel;
// Sheet 9: 2114s 3H and 3F form the 1Kx8 video RAM.
assign vram_addr    = addr[9:0];
// Sheet 9: 3U inhibits /WE while 8080 1F asserts WAIT.
assign vram_we      = cen_cpu && bus_wr && vram_sel && ready_n;
assign vram_din     = dout;
assign workram_addr = addr[7:0];
assign workram_we   = cen_cpu && bus_wr && ram_sel;
assign workram_din  = dout;
assign snd_wr       = cen_cpu && bus_wr && sound_wr;
assign snd_din      = dout;
// Sheet 8: 74259 output latch carries BGW, BALL ON and BINV.
assign bgw          = latch[5];
assign ball_on      = latch[6];
assign flip         = latch[7];

always @* begin
    din = 8'hff;
    if (!int_ack && bus_rd) begin
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
        ram_waited <= 0;
        ready_h_nq <= 0;
        ready_v_q <= 0;
    end else begin
        if (!ram_cycle) ram_waited <= 0;
        else if (cen_cpu) ram_waited <= 1;
        if (pxl_cen) begin
            if (h[6:4] == 3'b111) ready_h_nq <= 1;
            else if (h[4] && h[3:0] == 4'd0) ready_h_nq <= 0;
            if (h == 0 && v[4] && v[3:0] == 4'd0)
                ready_v_q <= !(v[7] && v[6] && v[5]);
        end
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
T8080s u_cpu(
`elsif IVERILOG
T8080s u_cpu(
`elsif JTFRAME_VZ80
T8080s u_cpu(
`else
T80s #(
    .Mode   ( 2 )
) u_cpu(
`endif
    .RESET_n( ~rst    ),
    .CLK    ( clk     ),
    .CEN    ( cen_cpu ),
    .WAIT_n ( ready_n ),
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
