/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    The Cliffhanger - Edward Randy board decoder (doc/cninja.cpp ::edrandy_map).
    Same shape as cninja - 2x deco16ic, decospr, deco_irq - with its own map, a
    1MB program, 5MB of sprites, and DECO 146 protection instead of the 104.

      000000-0fffff  program ROM (1MB)    194000-197fff  work RAM
      140000-14ffff  tilegen[0]           150000-15ffff  tilegen[1]
      188000-189fff  palette              1a4000-1a4007  deco_irq
      198000-19bfff  DECO 146 region 6 (protection)
      1a0000-1a3fff  DECO 146 region 8 (config; reads back 0)
      1ac000         sprite DMA flag (w)  1bc000-1bc7ff  sprite RAM

    Inputs, DIPs and the sound latch go THROUGH the 146, like cninja's 104, so
    there is no direct I/O window here.
*/
module jtedrandy_decoder(
    `include "jtcninja_decoder_ports.inc"
);

wire irq_cs    = !busn && en && A[23:16]==8'h1a && A[15:12]==4'h4;
wire objdma_cs = !busn && en && A[23:16]==8'h1a && A[15:12]==4'hc;
// The 146 answers two windows. region_selects[0]=6 fixes region 6 at 0x198000
// as the protection; region 8 at 0x1a0000 is configuration - the writes are
// ignorable and the reads come back 0, so game.v splits them on A[17].
wire prot6     = !busn && en && A[23:16]==8'h19 && A[15:14]==2'b10;
wire prot8     = !busn && en && A[23:16]==8'h1a && A[15:14]==2'b00;

assign rom_cs    = !busn && en && A[23:16] < 8'h10;          // 1MB
assign ram_cs    = !busn && en && A[23:16]==8'h19 && A[15:14]==2'b01;
assign pal_cs    = !busn && en && A[23:16]==8'h18 && A[15:13]==3'b100;
assign objram_cs = !busn && en && A[23:16]==8'h1b && A[15:11]==5'b11000;
assign pf0_cs    = !busn && en && A[23:16]==8'h14;
assign pf1_cs    = !busn && en && A[23:16]==8'h15;
assign prot_cs   = prot6 | prot8;
assign obj_copy  = objdma_cs & ~RnW;

// the soundlatch rides the 146; the board registers belong to other boards
assign snd_wr    = 0;
assign snd_dout  = 0;
assign prot_pri  = 0;
assign vprio0    = 0;
assign vprio1    = 0;
// edrandy must see every vblank from reset - see the port list
assign vbl_warmup = 0;

wire [15:0] irq_dout;

jtdeco_irq u_irq(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .en         ( en        ),
    .cs         ( irq_cs    ),
    .addr       ( A[3:1]    ),
    .cpu_dout   ( cpu_dout  ),
    .RnW        ( RnW       ),
    .vdump      ( vdump     ),
    .LVBL       ( LVBL      ),
    .LHBL       ( LHBL      ),
    .vbl_irq    ( vbl_irq   ),
    .vbl_ack    ( vbl_ack   ),
    .IPLn       ( IPLn      ),
    .dout       ( irq_dout  )
);

// MAME runs edrandy with empty_init: the 68k ROM is not scrambled.
assign cpu_din = !en      ? 16'd0     :
                 rom_cs   ? rom_data  :
                 ram_cs   ? work_dout :
                 pf0_cs   ? pf0_dout  :
                 pf1_cs   ? pf1_dout  :
                 pal_cs   ? pal_dout  :
                 objram_cs? obj_dout  :
                 prot_cs  ? prot_dout :
                 irq_cs   ? irq_dout  :
                            16'hffff;

wire _unused = &{ 1'b0, UDSn, LDSn, joystick1, joystick2, cab_1p, coin, dipsw };

endmodule
