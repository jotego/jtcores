/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    Dark Seal / Gate of Doom board decoder (doc/darkseal.cpp ::main_map).

      000000-07ffff  program ROM          100000-103fff  work RAM
      120000-1207ff  sprite RAM           140000-141fff  palette (RG + B ext)
      180000-18000f  I/O, DIRECT (no DECO 104)
      200000-203fff  tilegen[1] data      220000/222000  rowscroll
      240000-24000f  tilegen[1] control
      260000-263fff  tilegen[0] data      2a0000-2a000f  tilegen[0] control

    VBLANK -> IRQ6 (irq6_line_assert), acked by the write to 0x18000a.
*/
module jtdarkseal_decoder(
    `include "jtcninja_decoder_ports.inc"
);

// I/O window 0x180000-0x18000f
wire io      = en && A[23:16]==8'h18 && A[15:14]==2'b00;
wire dsw_cs  = io && A[3:1]==3'd0;          // 0x180000 DSW    (read)
wire p1p2_cs = io && A[3:1]==3'd1;          // 0x180002 P1_P2  (read)
wire sys_cs  = io && A[3:1]==3'd2;          // 0x180004 SYSTEM (read)
wire sprdma  = io && A[3:1]==3'd3 && ~RnW;  // 0x180006 sprite buffer
wire snd_cs  = io && A[3:1]==3'd4 && ~RnW;  // 0x180008 soundlatch
wire irqack  = io && A[3:1]==3'd5 && ~RnW;  // 0x18000a irq ack

assign rom_cs    = !busn && en && A[23:16] < 8'h08;
assign ram_cs    = !busn && en && A[23:16]==8'h10 && A[15:14]==2'b00;
assign pal_cs    = !busn && en && A[23:16]==8'h14;
assign objram_cs = !busn && en && A[23:16]==8'h12 && A[15:11]==5'd0;
assign pf0_cs    = !busn && en && (A[23:16]==8'h26 || A[23:16]==8'h2a);
assign pf1_cs    = !busn && en && (A[23:16]==8'h20 || A[23:16]==8'h22 || A[23:16]==8'h24);
assign prot_cs   = 0;                        // no protection device
assign obj_copy  = sprdma;
assign snd_wr    = snd_cs;
assign snd_dout  = cpu_dout[7:0];
assign prot_pri  = 0;
assign vprio0    = 0;
assign vprio1    = 0;

assign vbl_warmup = en;
assign vbl_ack   = irqack;
assign IPLn = (en & vbl_irq) ? ~3'd6 : ~3'd0;

// P1_P2 byte = {START, 1, B2, B1, dir[3:0]} per player.
// SYSTEM: [2:0]=COIN1/2/3, [3]=vblank (ACTIVE HIGH).
wire [15:0] p1p2_din = { cab_1p[1], 1'b1, joystick2[5:0],
                         cab_1p[0], 1'b1, joystick1[5:0] };
wire [15:0] sys_din  = { 8'hff, 4'b1111, ~LVBL, 1'b1, coin[1], coin[0] };

// maincpu data-line descramble D1<->D6, same map on both lanes. MAME does it
// once over the whole ROM in driver_init; the ROM is stored RAW in SDRAM and
// undone here, the only place it CAN live - it permutes bits inside a byte,
// which neither the MRA (byte/file level) nor the byte-serial download can
// express. Self-inverse, so undoing on read is the same permutation, and it
// covers the whole maincpu region so rom_cs alone is enough.
wire [15:0] rom_dec = { rom_data[15], rom_data[ 9], rom_data[13:10], rom_data[14], rom_data[8],
                        rom_data[ 7], rom_data[ 1], rom_data[ 5: 2], rom_data[ 6], rom_data[0] };

assign cpu_din = !en      ? 16'd0     :
                 rom_cs   ? rom_dec   :
                 ram_cs   ? work_dout :
                 dsw_cs   ? dipsw     :
                 p1p2_cs  ? p1p2_din  :
                 sys_cs   ? sys_din   :
                 pf0_cs   ? pf0_dout  :
                 pf1_cs   ? pf1_dout  :
                 pal_cs   ? pal_dout  :
                 objram_cs? obj_dout  :
                            16'hffff;

wire _unused = &{ 1'b0, rst, clk, vdump, LHBL, UDSn, LDSn, prot_dout,
                  joystick1[`JTFRAME_BUTTONS+3:6], joystick2[`JTFRAME_BUTTONS+3:6],
                  cab_1p[3:2], coin[3:2] };

endmodule
