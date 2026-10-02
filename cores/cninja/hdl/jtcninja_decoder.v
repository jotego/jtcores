/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    Caveman Ninja / Joe & Mac board decoder (doc/cninja.cpp ::cninja_map).

      000000-0bffff  program ROM          184000-187fff  work RAM (16kB)
      140000-14ffff  tilegen[0]           150000-15ffff  tilegen[1]
      190000-19000f  deco_irq             19c000-19dfff  palette
      1a4000-1a47ff  sprite RAM           1b4000         sprite DMA flag (w)
      1bc000-1bffff  DECO 104 protection / I/O / soundlatch

    Inputs, DIPs and the sound latch are read THROUGH the DECO 104, not mapped
    here, so this is the only board whose decoder has no cabinet ports in use.
    It is also the only one with a raster interrupt.
*/
module jtcninja_decoder(
    `include "jtcninja_decoder_ports.inc"
);

// Byte address is {A,1'b0}, so A[23:16] is the byte-address top.
wire        irq_cs    = !busn && en && A[23:16]==8'h19 && A[15:4]==12'h0;
wire        objdma_cs = !busn && en && A[23:16]==8'h1b && A[15:14]==2'b01;

assign rom_cs    = !busn && en && A[23:16] < 8'h0c;
assign ram_cs    = !busn && en && A[23:16]==8'h18 && A[15:14]==2'b01;
assign pal_cs    = !busn && en && A[23:16]==8'h19 && A[15:13]==3'b110;
assign objram_cs = !busn && en && A[23:16]==8'h1a && A[15:14]==2'b01;
assign pf0_cs    = !busn && en && A[23:16]==8'h14;
assign pf1_cs    = !busn && en && A[23:16]==8'h15;
assign prot_cs   = !busn && en && A[23:16]==8'h1b && A[15:14]==2'b11;
assign obj_copy  = objdma_cs & ~RnW;

assign vbl_warmup = en;   // cninja tolerates the reset-phase warmup

// the soundlatch and the board registers belong to other boards
assign snd_wr    = 0;
assign snd_dout  = 0;
assign prot_pri  = 0;
assign vprio0    = 0;
assign vprio1    = 0;

// ---------------------------------------------------------------------------
// deco_irq (0x190000): vblank -> IPL5, raster1 -> IPL3, raster2 -> IPL4
// ---------------------------------------------------------------------------
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
