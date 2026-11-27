/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-10-2026 */

module jtseicro_main(
    input              rst, cpu_rst, clk, cpu_cen, dip_pause,
    input              LVBL, irq_en, frisky, radial, tecfri,
    input       [8:0]  video_h,
    input       [1:0]  cab_1p, coin,
    input       [5:0]  joystick1, joystick2,
    input              service, dip_test,
    input       [7:0]  test_dip,
    output     [15:0]  cpu_addr,
    output      [7:0]  cpu_dout,
    output             sharedram_we, videoram_we, colorram_we,
    output             spriteram0_we, spriteram1_we, row_scroll_we,
    input       [7:0]  sharedram_dout, videoram_dout, colorram_dout,
    input       [7:0]  spriteram0_dout, row_scroll_dout,
    output     [14:0]  rom_addr,
    output             rom_cs,
    input       [7:0]  rom_data,
    input              rom_ok,
    output             ay_bdir, ay_bc1,
    input       [7:0]  ay_data,
    output             watchdog_clr,
    output             mcu_release_clk,
    output      [7:0]  debug_view
);

wire mreq_n, iorq_n, m1_n, rd_n, wr_n, rfsh_n, cpu_step, busak_n;
wire wait_n;
wire [1:0] pal_mode = (frisky || radial) ? 2'd1 : tecfri ? 2'd2 : 2'd0;
wire shared_cs, vram_cs, color_cs, obj0_cs, obj1_cs, scroll_cs;
wire in0_cs, in1_cs, test_cs;
wire [7:0] in0, in1, test_in;
reg [7:0] cpu_din;
reg irq_pending, lvbl_l;

assign rom_addr = cpu_addr[14:0];
assign sharedram_we = shared_cs & ~wr_n & cpu_step;
assign videoram_we = vram_cs & ~wr_n & cpu_step;
assign colorram_we = color_cs & ~wr_n & cpu_step;
assign spriteram0_we = obj0_cs & ~wr_n & cpu_step;
assign spriteram1_we = obj1_cs & ~wr_n & cpu_step;
assign row_scroll_we = scroll_cs & ~wr_n & cpu_step;
assign debug_view = cpu_addr[15:8];
// 5L6 uses /ZRB as buffered /RFSH; source qualification: ../doc/hardware_verification.md.
assign mcu_release_clk = mreq_n | ~rfsh_n;

jtseicro_cab u_cab(
    .frisky    ( frisky    ),
    .radial    ( radial    ),
    .cab_1p    ( cab_1p    ),
    .coin      ( coin      ),
    .joystick1 ( joystick1 ),
    .joystick2 ( joystick2 ),
    .service   ( service   ),
    .dip_test  ( dip_test  ),
    .test_dip  ( test_dip  ),
    .in0       ( in0       ),
    .in1       ( in1       ),
    .test_in   ( test_in   )
);

always @(posedge clk) begin
    lvbl_l <= LVBL;
    if(rst) begin
        irq_pending <= 0;
        lvbl_l <= 0;
    end else if(!irq_en) begin
        irq_pending <= 0;
    end else if(lvbl_l && !LVBL && dip_pause) begin
        irq_pending <= 1;
    end
end

always @* begin
    cpu_din = 8'hff;
    if(!rd_n) begin
        if(rom_cs) cpu_din = rom_data;
        else if(shared_cs) cpu_din = sharedram_dout;
        else if(vram_cs) cpu_din = videoram_dout;
        else if(color_cs) cpu_din = colorram_dout;
        else if(obj0_cs) cpu_din = spriteram0_dout;
        else if(scroll_cs) cpu_din = row_scroll_dout;
        else if(in0_cs) cpu_din = in0;
        else if(in1_cs) cpu_din = in1;
        else if(test_cs) cpu_din = test_in;
        else if(ay_bc1 && !ay_bdir) cpu_din = ay_data;
    end
end

jtseicro_decode u_decode(
    .addr         ( cpu_addr     ),
    .mreq_n       ( mreq_n       ),
    .iorq_n       ( iorq_n       ),
    .m1_n         ( m1_n         ),
    .rfsh_n       ( rfsh_n       ),
    .rd_n         ( rd_n         ),
    .wr_n         ( wr_n         ),
    .rom_cs       ( rom_cs       ),
    .shared_cs    ( shared_cs    ),
    .vram_cs      ( vram_cs      ),
    .color_cs     ( color_cs     ),
    .obj0_cs      ( obj0_cs      ),
    .obj1_cs      ( obj1_cs      ),
    .scroll_cs    ( scroll_cs    ),
    .in0_cs       ( in0_cs       ),
    .in1_cs       ( in1_cs       ),
    .test_cs      ( test_cs      ),
    .watchdog_clr ( watchdog_clr ),
    .ay_bdir      ( ay_bdir      ),
    .ay_bc1       ( ay_bc1       )
);

`ifndef NOMAIN
jtseicro_wait u_board_wait(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .mode     ( pal_mode  ),
    .h        ( video_h   ),
    .vblank_n ( LVBL      ),
    .addr     ( cpu_addr  ),
    .mreq_n   ( mreq_n    ),
    .rfsh_n   ( rfsh_n    ),
    .wait_n   ( wait_n    )
);

jtframe_z80wait #(
    .DEVCNT   ( 1 )
) u_rom_wait(
    .rst_n    ( ~cpu_rst            ),
    .clk      ( clk                 ),
    .cen_in   ( cpu_cen & dip_pause ),
    .cen_out  ( cpu_step            ),
    .gate     (                     ),
    .mreq_n   ( mreq_n              ),
    .iorq_n   ( iorq_n              ),
    .busak_n  ( busak_n             ),
    .dev_busy ( 1'b0                ),
    .rom_cs   ( rom_cs              ),
    .rom_ok   ( rom_ok              )
);

jtframe_z80 u_cpu(
    .rst_n   ( ~cpu_rst            ),
    .clk     ( clk                 ),
    .cen     ( cpu_step            ),
    .wait_n  ( wait_n              ),
    .int_n   ( ~irq_pending        ),
    .nmi_n   ( 1'b1                ),
    .busrq_n ( 1'b1                ),
    .m1_n    ( m1_n                ),
    .mreq_n  ( mreq_n              ),
    .iorq_n  ( iorq_n              ),
    .rd_n    ( rd_n                ),
    .wr_n    ( wr_n                ),
    .rfsh_n  ( rfsh_n              ),
    .halt_n  (                     ),
    .busak_n ( busak_n             ),
    .A       ( cpu_addr            ),
    .din     ( cpu_din             ),
    .dout    ( cpu_dout            )
);
`else
assign cpu_addr = 0;
assign cpu_dout = 0;
assign cpu_step = 0;
assign mreq_n = 1;
assign iorq_n = 1;
assign m1_n = 1;
assign rd_n = 1;
assign wr_n = 1;
assign rfsh_n = 1;
assign busak_n = 1;
assign wait_n = 1;
`endif

endmodule
