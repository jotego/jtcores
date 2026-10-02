/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    Vapor Trail / Kuhga board decoder (doc/vaportra.cpp ::main_map).
    2x deco16ic + MXC-06, no protection device, inputs read directly.

      000000-07ffff  program ROM          ffc000-ffffff  work RAM
      100000 PLAYERS r / priority[0] w    100002 COINS r / priority[1] w
      100004 DSW r                        100007 soundlatch w (byte)
      200000/202000  tilegen[1] data      240000-24000f  tilegen[1] control
      280000/282000  tilegen[0] data      2c0000-2c000f  tilegen[0] control
      300000 palette (RG) + 304000 (B ext)
      308001 irq6 ack r/w                 30c000 sprite DMA w
      318000-3187ff  sprite RAM, mirrored (vaportra.cpp mirror(0xce0000))

    VBLANK -> IRQ6 (irq6_line_assert), acked by a read OR write of 0x308001.
*/
module jtvaportra_decoder(
    `include "jtcninja_decoder_ports.inc"
);

// I/O window 0x100000-0x103fff
wire io      = en && A[23:16]==8'h10 && A[15:14]==2'b00;
wire play_cs = io && A[3:1]==3'd0;               // 0x100000 PLAYERS (read)
wire coin_cs = io && A[3:1]==3'd1;               // 0x100002 COINS   (read)
wire dsw_cs  = io && A[3:1]==3'd2;               // 0x100004 DSW     (read)
wire prio_cs = io && A[3:2]==2'd0 && ~RnW;       // 0x100000-3 priority (write)
wire snd_cs  = io && A[3:1]==3'd3 && ~RnW;       // 0x100007 soundlatch
wire irqack  = en && A[23:16]==8'h30 && A[15:13]==3'b100;          // 0x308001
wire sprdma  = en && A[23:16]==8'h30 && A[15:13]==3'b110 && ~RnW;  // 0x30c000

assign rom_cs    = !busn && en && A[23:16] < 8'h08;
assign ram_cs    = !busn && en && A[23:16]==8'hff && A[15:14]==2'b11;
assign pal_cs    = !busn && en && A[23:16]==8'h30 &&
                                 (A[15:13]==3'b000 || A[15:13]==3'b010);
// partial decode: covers 0x318000 and the 0xff8000 mirror the game writes through
assign objram_cs = !busn && en && A[21] & A[20] & A[16] & A[15] & ~|A[14:11];
assign pf0_cs    = !busn && en && (A[23:16]==8'h28 || A[23:16]==8'h2c);
assign pf1_cs    = !busn && en && (A[23:16]==8'h20 || A[23:16]==8'h24);
assign prot_cs   = 0;                             // no protection device
assign obj_copy  = sprdma;
assign snd_wr    = snd_cs;
assign snd_dout  = cpu_dout[7:0];
assign prot_pri  = 0;

assign vbl_warmup = en;
assign vbl_ack   = irqack & ~(UDSn & LDSn);
assign IPLn = (en & vbl_irq) ? ~3'd6 : ~3'd0;

// m_priority[0] = playfield draw order, [1] = sprite-behind-fg threshold
reg [15:0] prio0, prio1;
always @(posedge clk) if( prio_cs ) begin
    if( ~A[1] ) prio0 <= cpu_dout;   // 0x100000
    else        prio1 <= cpu_dout;   // 0x100002
end
assign vprio0 = prio0;
assign vprio1 = prio1;

// PLAYERS uses the darkseal P1_P2 layout {START,1,B2,B1,R,L,D,U} per player.
// COINS: [0]coin1 [1]coin2 [2]service [3]vblank (ACTIVE HIGH). service is not
// plumbed into main yet -> idle (1'b1); wire it through game.v with the test path.
wire [15:0] play_din = { cab_1p[1], 1'b1, joystick2[5:0],
                         cab_1p[0], 1'b1, joystick1[5:0] };
wire [15:0] coin_din = { 8'hff, 4'b1111, ~LVBL, 1'b1, coin[1], coin[0] };

// maincpu data-line descramble D7<->D0, same map on both lanes. See the note in
// jtdarkseal_decoder: the ROM is stored raw and undone on read. Self-inverse.
wire [15:0] rom_dec = { rom_data[ 8], rom_data[14:9], rom_data[15],
                        rom_data[ 0], rom_data[ 6:1], rom_data[ 7] };

assign cpu_din = !en      ? 16'd0     :
                 rom_cs   ? rom_dec   :
                 ram_cs   ? work_dout :
                 play_cs  ? play_din  :
                 coin_cs  ? coin_din  :
                 dsw_cs   ? dipsw     :
                 pf0_cs   ? pf0_dout  :
                 pf1_cs   ? pf1_dout  :
                 pal_cs   ? pal_dout  :
                 objram_cs? obj_dout  :
                            16'hffff;

wire _unused = &{ 1'b0, rst, vdump, LHBL, prot_dout,
                  joystick1[`JTFRAME_BUTTONS+3:6], joystick2[`JTFRAME_BUTTONS+3:6],
                  cab_1p[3:2], coin[3:2], A[22], A[19:17] };

endmodule
