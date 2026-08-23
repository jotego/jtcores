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

// the soundlatch and the board registers belong to other boards
assign snd_wr    = 0;
assign snd_dout  = 0;
assign prot_pri  = 0;
assign vprio0    = 0;
assign vprio1    = 0;

// ---------------------------------------------------------------------------
// deco_irq (0x190000): vblank -> IPL5, raster1 -> IPL3, raster2 -> IPL4
// ---------------------------------------------------------------------------
reg  [ 7:0] rs_line;      // raster IRQ target scanline
reg         rs_target;    // 0=raster1 (IPL3), 1=raster2 (IPL4)
reg         rs_mask;
reg         ras_irq;
reg  [ 8:0] vdump_l;
wire [ 7:0] irq_status = { 1'b1, 1'b0, ras_irq, vbl_irq, 2'b00, ~LVBL, ~LHBL };

assign vbl_ack = irq_cs && !RnW && A[3:1]==3'd2;   // vblank_irq_ack_w

always @* begin
    if( !en                      ) IPLn = ~3'd0;
    else if( vbl_irq             ) IPLn = ~3'd5;
    else if( ras_irq & rs_target ) IPLn = ~3'd4;
    else if( ras_irq             ) IPLn = ~3'd3;
    else                           IPLn = ~3'd0;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vdump_l <= 0; ras_irq <= 0; rs_line <= 0; rs_target <= 0; rs_mask <= 1;
    end else begin
        vdump_l <= vdump;
        // deco_irq only fires when the programmed line is inside the visible
        // area (set_raw ..., 8, 248). Without the lower bound a game that
        // parks rs_line=0 to DISABLE the raster gets a spurious raster1 IRQ.
        if( !rs_mask && rs_line>=8'd8 && rs_line<=8'd247 &&
            vdump=={1'b0,rs_line} && vdump_l!={1'b0,rs_line} ) ras_irq <= 1;
        if( irq_cs && !RnW ) case( A[3:1] )
            3'd0: begin rs_target<=cpu_dout[4]; rs_mask<=cpu_dout[1];
                        if( cpu_dout[1] ) ras_irq<=0; end   // mask acks raster
            3'd1: rs_line <= cpu_dout[7:0];
            default:;
        endcase
        // raster_irq_ack_r: reading offset 2 acks the raster IRQ
        if( irq_cs && RnW && A[3:1]==3'd2 ) ras_irq <= 0;
    end
end

// byte registers on the low lane (doc/deco_irq.cpp map)
//   1 (0x190002) scanline_r   2 (0x190004) raster ack   3 (0x190006) status_r
reg [15:0] irq_dout;
always @* begin
    case( A[3:1] )
        3'd1:    irq_dout = { 8'hff, rs_line    };
        3'd3:    irq_dout = { 8'hff, irq_status };
        default: irq_dout = 16'hffff;   // raster_irq_ack_r returns 0xff
    endcase
end

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
