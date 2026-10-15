module jtseicro_main(
    input              rst, clk, cpu_cen, dip_pause,
    input              LVBL, irq_en,
    input       [1:0]  cab_1p, coin,
    input       [4:0]  joystick1, joystick2,
    input              service, dip_test,
    input       [1:0]  test_dip,
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
    output      [7:0]  debug_view
);

wire mreq_n, iorq_n, m1_n, rd_n, wr_n, rfsh_n, cpu_step;
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
assign in0 = ~{cab_1p,coin,joystick1[0],joystick1[1],joystick1[2],joystick1[3]};
assign in1 = {~joystick2[4],~joystick1[4],1'b0,~service,
              ~joystick2[0],~joystick2[1],~joystick2[2],~joystick2[3]};
assign test_in = {6'd0,test_dip[1],test_dip[0] | ~dip_test};
assign debug_view = cpu_addr[15:8];

always @(posedge clk) begin
    lvbl_l <= LVBL;
    if(rst) begin
        irq_pending <= 0;
        lvbl_l <= 0;
    end else if(!m1_n && !iorq_n) begin
        irq_pending <= 0;
    end else if(lvbl_l && !LVBL && irq_en && dip_pause) begin
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
jtframe_z80_romwait u_cpu(
    .rst_n   ( ~rst                ),
    .clk     ( clk                 ),
    .cen     ( cpu_cen & dip_pause ),
    .cpu_cen ( cpu_step            ),
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
    .busak_n (                     ),
    .A       ( cpu_addr            ),
    .din     ( cpu_din             ),
    .dout    ( cpu_dout            ),
    .rom_cs  ( rom_cs              ),
    .rom_ok  ( rom_ok              )
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
`endif

endmodule
