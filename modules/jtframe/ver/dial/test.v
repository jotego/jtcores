`define  JTFRAME_DIALEMU_LEFT 0

module test;

reg        clk, rst;
wire [1:0] dial_x, dial_y;
reg  [1:0] spinner;

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
    #25_000 $finish;
end

initial begin
    clk = 0;
    forever #10 clk = ~clk;
end

initial begin
    rst = 1;
    spinner = 0;
    #500;
    rst = 0;
    #100;
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    spinner[0] = 1;
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
    #800 spinner[1] = ~spinner[1];
end

jtframe_dial uut(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .LHBL       ( 1'b0      ),
    // emulation based on joysticks
    .joystick1  ( ~10'h0    ),
    .joystick2  ( ~10'h0    ),
    .spinner_1  ( { spinner, 7'd0 } ),
    .sensty     ( 2'd0      ),
    .spinner_2  ( 9'd0      ),
    .dial_x     ( dial_x    ),
    .dial_y     ( dial_y    )
);

jt4701 u_dial(
    .clk        ( clk       ),
    .rst        ( rst       ),
    .x_in       ( dial_x    ),
    .y_in       ( dial_y    ),
    .rightn     ( 1'b1      ),
    .leftn      ( 1'b1      ),
    .middlen    ( 1'b1      ),
    .x_rst      ( rst       ),
    .y_rst      ( rst       ),
    .csn        ( 1'b1      ),        // chip select
    .uln        ( 1'b1      ),        // byte selection
    .xn_y       ( 1'b1      ),        // select x or y for reading
    .cfn        (           ),        // counter flag
    .sfn        (           ),        // switch flag
    .dout       (           )
);

endmodule