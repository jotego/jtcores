/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    Crude Buster / Two Crude board decoder (doc/cbuster.cpp ::main_map).

      000000-07ffff  program ROM          080000-083fff  work RAM
      0a0000-0a7fff  tilegen[0] data + rowscroll   0b5000  tilegen[0] control
      0a8000-0affff  tilegen[1] data + rowscroll   0b6000  tilegen[1] control
      0b0000-0b07ff  sprite RAM           0b8000-0b9fff  palette (RG + B ext)
      0bc000 P1_P2 r / sprite DMA w       0bc002 DSW r / soundlatch w
      0bc004 TC-4 protection r/w          0bc006 COINS r / IRQ4 ack w

    VBLANK -> IRQ4 (irq4_line_assert).
*/
module jtcbuster_decoder(
    `include "jtcninja_decoder_ports.inc"
);

// I/O window 0x0bc000-0x0bc007, A[3:1] picks the register
wire io      = en && A[23:16]==8'h0b && A[15:12]==4'hc;
wire p1p2_cs = io && A[3:1]==3'd0;            // 0x0bc000 P1_P2 (read)
wire sprdma  = io && A[3:1]==3'd0 && ~RnW;    // 0x0bc000 sprite DMA (write)
wire dsw_cs  = io && A[3:1]==3'd1;            // 0x0bc002 DSW   (read)
wire snd_cs  = io && A[3:1]==3'd1 && ~RnW;    // 0x0bc002 soundlatch (write)
wire prot_reg= io && A[3:1]==3'd2;            // 0x0bc004 prot  (r/w)
wire coin_cs = io && A[3:1]==3'd3;            // 0x0bc006 COINS (read)
wire irqack  = io && A[3:1]==3'd3 && ~RnW;    // 0x0bc006 IRQ4 ack (write)

assign rom_cs    = !busn && en && A[23:16] < 8'h08;
assign ram_cs    = !busn && en && A[23:16]==8'h08 && A[15:14]==2'b00;
assign pal_cs    = !busn && en && A[23:16]==8'h0b && A[15:13]==3'b100;
assign objram_cs = !busn && en && A[23:16]==8'h0b && A[15:11]==5'd0;
assign pf0_cs    = !busn && en && ((A[23:16]==8'h0a && ~A[15]) ||
                                   (A[23:16]==8'h0b && A[15:12]==4'h5));
assign pf1_cs    = !busn && en && ((A[23:16]==8'h0a &&  A[15]) ||
                                   (A[23:16]==8'h0b && A[15:12]==4'h6));
assign prot_cs   = 0;                          // the TC-4 is HLE'd below
assign obj_copy  = sprdma;
assign snd_wr    = snd_cs;
assign snd_dout  = cpu_dout[7:0];
assign vprio0    = 0;
assign vprio1    = 0;

assign vbl_warmup = en;
assign vbl_ack   = irqack;
assign IPLn = (en & vbl_irq) ? ~3'd4 : ~3'd0;

// P1_P2: per player byte = {START,B3,B2,B1,R,L,D,U} = {cab_1p, joystick[6:0]}.
// COINS: [2:0]=COIN1/2/3, [3]=vblank (ACTIVE HIGH).
wire [15:0] p1p2_din = { cab_1p[1], joystick2[6:0],
                         cab_1p[0], joystick1[6:0] };
wire [15:0] coin_din = { 8'hff, 4'hf, ~LVBL, coin[2], coin[1], coin[0] };

// ---------------------------------------------------------------------------
// TC-4 registered-PAL protection HLE (doc/cbuster.cpp ::prot_w)
// ---------------------------------------------------------------------------
// The CPU writes a magic value and reads m_prot back as a boot gate; the SAME
// writes carry the layer priority m_pri - there is no priority register on this
// board, the playfield draw order comes from this device. MAME masks the write
// by mem_mask before matching, so mask cpu_dout by the active byte lanes:
// otherwise a byte write arrives with a stale high byte and never matches.
reg  [15:0] prot = 16'h000e;
reg         pri  = 1'b0;
wire [15:0] pw   = cpu_dout & { {8{~UDSn}}, {8{~LDSn}} };
// Latch on the FALLING edge of the data strobes and once per write: the address
// decode is valid a few cycles before the 68000 asserts UDSn/LDSn, so sampling
// on the address alone reads both strobes high (pw=0, always matching the
// 0x0000 case -> prot stuck at 0x0e).
reg  ds_l;
wire ds = prot_reg & ~RnW & (~UDSn | ~LDSn);
always @(posedge clk) ds_l <= ds;
always @(posedge clk, posedge rst) begin
    if( rst ) begin prot <= 16'h000e; pri <= 1'b0; end
    else if( ds && ~ds_l ) case( pw )
        16'h9a00: prot <= 16'h0000;
        16'h00aa: prot <= 16'h0074;
        16'h0200: prot <= 16'h6300;
        16'h009a: prot <= 16'h000e;
        16'h0055: prot <= 16'h001e;
        16'h000e: begin prot <= 16'h000e; pri <= 1'b0; end // start / level 0
        16'h0000: begin prot <= 16'h000e; pri <= 1'b0; end
        16'h00f1: begin prot <= 16'h0036; pri <= 1'b1; end // level 1
        16'h0080: begin prot <= 16'h002e; pri <= 1'b1; end // level 2
        16'h0040: begin prot <= 16'h001e; pri <= 1'b1; end // level 3
        16'h00c0: begin prot <= 16'h003e; pri <= 1'b0; end // level 4
        16'h00ff: begin prot <= 16'h0076; pri <= 1'b1; end // level 5
        default:;
    endcase
end
assign prot_pri = pri;

// maincpu data-line descramble (init_twocrude), a DIFFERENT permutation per
// lane - which is exactly why it cannot live in the MRA or the byte-serial
// download. Self-inverse, so undoing on read is the same permutation.
//   H out={in4,in6,in7,in5,in3:0}   L out={in7,in1,in5,in4,in6,in2,in3,in0}
// verified vs MAME: SSP=0x084000, PC=0x600, 0x606 = 46 FC 27 00
wire [15:0] rom_dec = {
    rom_data[12], rom_data[14], rom_data[15], rom_data[13], rom_data[11:8],
    rom_data[ 7], rom_data[ 1], rom_data[ 5], rom_data[ 4],
    rom_data[ 6], rom_data[ 2], rom_data[ 3], rom_data[ 0] };

assign cpu_din = !en      ? 16'd0     :
                 rom_cs   ? rom_dec   :
                 ram_cs   ? work_dout :
                 dsw_cs   ? dipsw     :
                 p1p2_cs  ? p1p2_din  :
                 coin_cs  ? coin_din  :
                 prot_reg ? prot      :
                 pf0_cs   ? pf0_dout  :
                 pf1_cs   ? pf1_dout  :
                 pal_cs   ? pal_dout  :
                 objram_cs? obj_dout  :
                            16'hffff;

wire _unused = &{ 1'b0, vdump, LHBL, prot_dout, cab_1p[3:2], coin[3] };

endmodule
