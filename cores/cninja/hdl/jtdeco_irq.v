/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    Data East deco_irq (doc/deco_irq.cpp): vblank plus two programmable raster
    interrupts. Used by cninja (0x19000x) and edrandy (0x1a4000); the board
    decodes the window and passes the offset.

    IPL levels are fixed by the chip: vblank 5, raster2 4, raster1 3.
    The vblank latch itself lives in jtcninja_main, shared by every board.

    Byte registers on the low lane:
      0 write  [4]=raster target (0=raster1, 1=raster2)  [1]=raster mask
      1 r/w    raster scanline
      2 write  vblank ack        2 read  raster ack (returns 0xff)
      3 read   status
*/
module jtdeco_irq(
    input             rst,
    input             clk,
    input             en,
    input             cs,
    input      [ 3:1] addr,
    input      [15:0] cpu_dout,
    input             RnW,
    input      [ 8:0] vdump,
    input             LVBL,
    input             LHBL,
    input             vbl_irq,
    output            vbl_ack,
    output reg [ 2:0] IPLn,
    output reg [15:0] dout
);

reg  [ 7:0] rs_line;
reg         rs_target, rs_mask, ras_irq;
reg  [ 8:0] vdump_l;
wire [ 7:0] status = { 1'b1, 1'b0, ras_irq, vbl_irq, 2'b00, ~LVBL, ~LHBL };

assign vbl_ack = cs && !RnW && addr==3'd2;

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
        // The chip only fires the raster IRQ when the programmed line is inside
        // the visible area (set_raw ..., 8, 248). Without the lower bound a game
        // that parks rs_line=0 to DISABLE the raster gets a spurious raster1.
        if( !rs_mask && rs_line>=8'd8 && rs_line<=8'd247 &&
            vdump=={1'b0,rs_line} && vdump_l!={1'b0,rs_line} ) ras_irq <= 1;
        if( cs && !RnW ) case( addr )
            3'd0: begin rs_target<=cpu_dout[4]; rs_mask<=cpu_dout[1];
                        if( cpu_dout[1] ) ras_irq<=0; end   // mask acks raster
            3'd1: rs_line <= cpu_dout[7:0];
            default:;
        endcase
        if( cs && RnW && addr==3'd2 ) ras_irq <= 0;         // raster_irq_ack_r
    end
end

always @* begin
    case( addr )
        3'd1:    dout = { 8'hff, rs_line };
        3'd3:    dout = { 8'hff, status  };
        default: dout = 16'hffff;
    endcase
end

endmodule
