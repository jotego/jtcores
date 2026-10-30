/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

module jtapach3_roadcpu(
    input             rst,
    input             clk,
    input             cen,
    input             sub_reset_n,
    input             halt,
    input             vblank,
    output     [12:0] z80ram_addr,
    output     [ 7:0] z80ram_din,
    input      [ 7:0] z80ram_dout,
    output            z80ram_we,
    output     [ 8:1] road_x_ram_addr,
    output     [15:0] road_x_ram_din,
    output     [ 1:0] road_x_ram_we
);

wire [15:0] addr;
wire [7:0] dout;
wire mreq_n, iorq_n, m1_n, rd_n, wr_n, rfsh_n, busak_n;
wire cpu_mem = !mreq_n && rfsh_n && busak_n;
wire ram_cs = cpu_mem && addr <= 16'h1fff;
wire road_cs = cpu_mem && addr[15];
reg irq, old_vblank, started;

assign z80ram_addr     = addr[12:0];
assign z80ram_din      = dout;
assign z80ram_we       = !rst && started && sub_reset_n && ram_cs && !wr_n && cen;
assign road_x_ram_addr = dout;
assign road_x_ram_din  = {{4{addr[11]}},addr[11:0]};
assign road_x_ram_we   = {2{!rst && started && sub_reset_n && road_cs && !wr_n && cen}};

always @(posedge clk) begin
    if (rst) begin
        irq <= 0;
        old_vblank <= 0;
        started <= 0;
    end else begin
        old_vblank <= vblank;
        if (!sub_reset_n) started <= 1;
        if (vblank && !old_vblank) irq <= 1;
        if (!m1_n && !iorq_n) irq <= 0;
    end
end

jtframe_z80 u_cpu (
    .rst_n   ( ~rst && started && sub_reset_n        ),
    .clk     ( clk                                   ),
    .cen     ( cen                                   ),
    .wait_n  ( 1'b1                                  ),
    .int_n   ( ~irq                                  ),
    .nmi_n   ( 1'b1                                  ),
    .busrq_n ( ~halt                                 ),
    .m1_n    ( m1_n                                  ),
    .mreq_n  ( mreq_n                                ),
    .iorq_n  ( iorq_n                                ),
    .rd_n    ( rd_n                                  ),
    .wr_n    ( wr_n                                  ),
    .rfsh_n  ( rfsh_n                                ),
    .halt_n  (                                       ),
    .busak_n ( busak_n                               ),
    .A       ( addr                                  ),
    .din     ( ram_cs && !rd_n ? z80ram_dout : 8'hff ),
    .dout    ( dout                                  )
);

endmodule
