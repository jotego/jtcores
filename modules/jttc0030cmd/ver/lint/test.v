// Smoke test for jttc0030cmd: elaborate + run the MCU for a few thousand
// clocks with an idle 68k bus.  Value is mainly the verilator lint that
// simunit runs before this; the sim just proves the wrapper drives without
// crashing.  No ROM is loaded, so the MCU simply fetches 0x00 and spins.
module test;
    reg        clk = 0, rst = 1;
    reg  [1:0] presc = 0;
    wire       cen = presc == 2'd3;   // divide-by-4 MCU clock enable

    always #10 clk = ~clk;
    always @(posedge clk) presc <= presc + 2'd1;

    // idle 68k host bus
    reg         cs  = 0, rnw = 1;
    reg  [10:0] addr = 0;
    reg  [ 7:0] din  = 0;
    wire [ 7:0] dout;
    wire        dtack_n;
    wire [ 7:0] pa_out, pb_out, pc_out;

    jttc0030cmd uut(
        .rst      ( rst      ),
        .clk      ( clk      ),
        .cen      ( cen      ),
        .cs       ( cs       ),
        .addr     ( addr     ),
        .din      ( din      ),
        .dout     ( dout     ),
        .rnw      ( rnw      ),
        .dtack_n  ( dtack_n  ),
        .int1     ( 1'b0     ),
        .nmi_n    ( 1'b1     ),
        .pa_in    ( 8'hff    ),
        .pb_in    ( 8'hff    ),
        .pc_in    ( 8'hff    ),
        .pa_out   ( pa_out   ),
        .pb_out   ( pb_out   ),
        .pc_out   ( pc_out   ),
        .an       ( 8'h00    ),
        .mrom_addr (          ),
        .mrom_data ( 8'd0     ),
        .eprom_addr(          ),
        .eprom_data( 8'd0     )
    );

    initial begin
        repeat(20)   @(posedge clk);
        rst = 0;
        repeat(4000) @(posedge clk);
        $display("PASS");
        $finish;
    end
endmodule
