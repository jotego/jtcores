`timescale 1ns / 1ps

// Two chips get the same clock enable, which restarts when reset is released
// (like jtframe_gated_cen), and the same register writes. Their resets end in
// the same cycle, but one reset starts an odd number of cen pulses earlier.
// The chip outputs must not depend on how long reset lasted.

module test;

`include "test_tasks.vh"

localparam RST_END = 2000;

reg         clk=0, rst_long=1, rst_short=0, cs_n=1, wr_n=1, rd_n=1, a0=0;
reg  [ 7:0] din=0;
reg  [ 1:0] div=0;
integer     cycles=0, errors=0;
reg         irq_seen=0;
wire        cen = div==3;
wire [ 7:0] dout_short, dout_long;
wire        irq_short, irq_long;

always #31.25 clk = ~clk; // 16 MHz, cen at 4 MHz

always @(posedge clk) begin
    cycles    <= cycles + 1;
    rst_long  <= cycles < RST_END;
    rst_short <= cycles >= 28*4+4 && cycles < RST_END; // 28+1 cen pulses less
    div       <= rst_long ? div+1'd1 : (cycles==RST_END ? 2'd0 : div+1'd1);
    if( !irq_long ) irq_seen <= 1;
    if( cycles > RST_END+8 && (dout_short!=dout_long || irq_short!=irq_long) ) errors <= errors+1;
end

task write(input [7:0] a, input [7:0] d); begin
    @(posedge clk) begin cs_n <= 0; wr_n <= 0; a0 <= 0; din <= a; end
    repeat(8) @(posedge clk);
    @(posedge clk) begin cs_n <= 1; wr_n <= 1; end
    repeat(200) @(posedge clk);
    @(posedge clk) begin cs_n <= 0; wr_n <= 0; a0 <= 1; din <= d; end
    repeat(8) @(posedge clk);
    @(posedge clk) begin cs_n <= 0; wr_n <= 1; rd_n <= 0; end // read the status
    repeat(400) @(posedge clk);
end endtask

initial begin
    wait( cycles==RST_END+500 );
    write(8'h10, 8'hff);    // timer A high
    write(8'h11, 8'h00);    // timer A low
    write(8'h12, 8'hf0);    // timer B
    write(8'h14, 8'h3f);    // load and enable both timers and IRQs
    repeat(80_000) @(posedge clk);
    write(8'h14, 8'h3f);
    repeat(20_000) @(posedge clk);
    assert_msg( irq_seen, "the timers did not fire");
    assert_msg( errors==0, "the chip output depends on the reset length");
    pass();
end

jtikaopm uut_long(
    .rst    ( rst_long   ),
    .clk    ( clk        ),
    .cen    ( cen        ),
    .cs_n   ( cs_n       ),
    .rd_n   ( rd_n       ),
    .wr_n   ( wr_n       ),
    .a0     ( a0         ),
    .din    ( din        ),
    .dout   ( dout_long  ),
    .ct1    (            ),
    .ct2    (            ),
    .irq_n  ( irq_long   ),
    .left   (            ),
    .right  (            )
);

jtikaopm uut_short(
    .rst    ( rst_short  ),
    .clk    ( clk        ),
    .cen    ( cen        ),
    .cs_n   ( cs_n       ),
    .rd_n   ( rd_n       ),
    .wr_n   ( wr_n       ),
    .a0     ( a0         ),
    .din    ( din        ),
    .dout   ( dout_short ),
    .ct1    (            ),
    .ct2    (            ),
    .irq_n  ( irq_short  ),
    .left   (            ),
    .right  (            )
);

endmodule
