/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-11-2026 */

module jtwrpwrp_main(
    input             clk,
    input             rst,
    input             cen_cpu,
    input             paddle_board,
    input             irq,
    input             wrq_n,
    input             vs,
    input      [7:0]  dip1,
    input      [7:0]  dip2,
    input      [7:0]  switches,
    input      [7:0]  vol,
    output     [13:0] maincpu_addr,
    input      [7:0]  maincpu_data,
    output     [10:0] gfx_cpu_addr,
    output            gfx_cpu_rd,
    input      [7:0]  gfx1_data,
    output     [9:0]  vram1_addr,
    output            vram1_we,
    output     [7:0]  vram1_din,
    input      [7:0]  vram1_dout,
    output     [9:0]  vram2_addr,
    output            vram2_we,
    output     [7:0]  vram2_din,
    input      [7:0]  vram2_dout,
    output     [9:0]  workram_addr,
    output            workram_we,
    output     [7:0]  workram_din,
    input      [7:0]  workram_dout,
    output reg [7:0]  ball_h,
    output reg [7:0]  ball_v,
    output     [7:0]  outputs,
    output            effects_wr,
    output            music1_wr,
    output            music2_wr,
    output     [5:0]  snd_din
);

wire [15:0] addr;
wire [7:0] dout;
wire m1_n, mreq_n, iorq_n, rd_n, wr_n;
wire int_ack = !m1_n && !iorq_n;
wire bus_rd = !int_ack && !rd_n && (!mreq_n || !iorq_n);
wire bus_wr = !wr_n && (!mreq_n || !iorq_n);
// Sheet 1: 2E takes A15 on A and A14 on B.
wire [1:0] quadrant = {addr[14], paddle_board ? addr[13] : addr[15]};
wire rom_sel = quadrant == 2'd0;
wire ram_sel = quadrant == 2'd1;
wire vram_sel = quadrant == 2'd2;
wire io_sel = quadrant == 2'd3;
wire cg_sel = vram_sel && addr[11];
wire vr1_sel = vram_sel && addr[11:10] == 2'b00;
wire vr2_sel = vram_sel && addr[11:10] == 2'b01;
wire [1:0] io_group = addr[5:4];
wire io_wr = cen_cpu && bus_wr && io_sel;
wire out0_wr = io_wr && io_group == 2'd0;
wire watchdog_clear = out0_wr && addr[1:0] == 2'd3;
wire vs_tick;
wire [3:0] watchdog;
wire cpu_rst = rst || watchdog[3];
// Sheet 1: 2C combines /V-RAM and /WRQ for the 8224 READY input.
wire ready_n = int_ack || !vram_sel || wrq_n;
reg [7:0] din;
reg [7:0] latch;

assign maincpu_addr = addr[13:0];
assign gfx_cpu_addr = addr[10:0];
assign gfx_cpu_rd   = bus_rd && cg_sel;
assign vram1_addr   = addr[9:0];
assign vram1_we     = cen_cpu && bus_wr && vr1_sel && ready_n;
assign vram1_din    = dout;
assign vram2_addr   = addr[9:0];
assign vram2_we     = cen_cpu && bus_wr && vr2_sel && ready_n;
assign vram2_din    = dout;
assign workram_addr = addr[9:0];
assign workram_we   = cen_cpu && bus_wr && ram_sel;
assign workram_din  = dout;
assign outputs      = latch;
// 6P and 2E decode the 5A, 5B and 5U latch strobes.
assign effects_wr   = out0_wr && addr[1:0] == 2'd2;
assign music1_wr    = io_wr && io_group == 2'd1;
assign music2_wr    = io_wr && io_group == 2'd2;
assign snd_din      = dout[5:0];

always @* begin
    din = 8'hff;
    if (bus_rd) begin
        if (rom_sel) din = maincpu_data;
        else if (ram_sel) din = workram_dout;
        else if (vr1_sel) din = vram1_dout;
        else if (vr2_sel) din = vram2_dout;
        else if (cg_sel) din = gfx1_data;
        else if (io_sel) begin
            case (io_group)
                2'd0: din[0] = switches[addr[2:0]];
                2'd1: din = vol;
                2'd2: din[0] = dip1[addr[2:0]];
                2'd3: din[0] = dip2[addr[2:0]];
            endcase
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ball_h <= 0;
        ball_v <= 0;
    end else if (out0_wr) begin
        if (addr[1:0] == 2'd0) ball_h <= dout;
        if (addr[1:0] == 2'd1) ball_v <= dout;
    end
end

// 7C QD feeds Q1 and 1D, resetting 1F and 6L.
always @(posedge clk or posedge cpu_rst) begin
    if (cpu_rst) latch <= 0;
    else if (io_wr && io_group == 2'd3) latch[addr[2:0]] <= dout[0];
end

jtframe_edge_pulse #(
    .NEGEDGE ( 1 )
) u_watchdog_clk(
    .rst    ( rst     ),
    .clk    ( clk     ),
    .cen    ( 1'b1    ),
    .sigin  ( vs      ),
    .pulse  ( vs_tick )
);

// 6P/2E, 2D and 2W clear 7C.
jtframe_counter #(
    .W ( 4 )
) u_watchdog(
    .rst ( rst || watchdog_clear ),
    .clk ( clk                   ),
    .cen ( vs_tick               ),
    .cnt ( watchdog              )
);

`ifdef VERILATOR
T8080s u_cpu(
`elsif IVERILOG
T8080s u_cpu(
`elsif JTFRAME_VZ80
T8080s u_cpu(
`else
T80s #(
    .Mode ( 2 )
) u_cpu(
`endif
    .RESET_n ( ~cpu_rst ),
    .CLK     ( clk      ),
    .CEN     ( cen_cpu  ),
    .WAIT_n  ( ready_n  ),
    .INT_n   ( ~irq     ),
    .NMI_n   ( 1'b1     ),
    .BUSRQ_n ( 1'b1     ),
    .OUT0    ( 1'b0     ),
    .DI      ( din      ),
    .M1_n    ( m1_n     ),
    .MREQ_n  ( mreq_n   ),
    .IORQ_n  ( iorq_n   ),
    .RD_n    ( rd_n     ),
    .WR_n    ( wr_n     ),
    .RFSH_n  (          ),
    .HALT_n  (          ),
    .BUSAK_n (          ),
    .A       ( addr     ),
    .DOUT    ( dout     )
);

endmodule
