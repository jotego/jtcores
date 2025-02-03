module test;

`include "test_tasks.vh"

wire       rst, clk;
reg        shift, ctrl, inc, dec;
reg  [7:0] key_digit, key_shadow;
wire [7:0] debug_bus;
integer    shadow=0;

initial begin
    shift     = 0;
    ctrl      = 0;
    inc       = 0;
    dec       = 0;
    key_digit = 0;
    @(negedge rst);
    repeat(2) @(posedge clk);
    assert_msg(debug_bus==0,"debug_bus must be zero after reset");

    repeat(240) begin
        repeat(2) @(posedge clk);
        inc = 1;
        shadow = shadow+1;
        repeat(2) @(posedge clk);
        inc = 0;
        assert_msg(debug_bus==shadow[7:0],"debug_bus increment failed");
    end

    repeat(40) begin
        repeat(2) @(posedge clk);
        dec = 1;
        shadow = shadow-1;
        repeat(2) @(posedge clk);
        dec = 0;
        assert_msg(debug_bus==shadow[7:0],"debug_bus decrement failed");
    end

    ctrl=1;
    inc=1;
    repeat(2) @(posedge clk);
    assert_msg(debug_bus==0,"debug_bus must be zero after with ctrl+inc");
    shadow=0;

    ctrl=0;
    inc=0;

    shift=1;
    repeat(3) begin
        repeat(2) @(posedge clk);
        inc = 1;
        repeat(2) @(posedge clk);
        inc = 0;
        shadow = shadow+16;
        assert_msg(debug_bus==shadow[7:0],"debug_bus +16 increment failed");
    end

    ctrl=1;
    inc=1;
    repeat(2) @(posedge clk);
    shadow=0;

    ctrl=0;
    inc=0;
    key_digit=1;
    shadow=0;
    shift=1;
    repeat(8) begin
        repeat(2) @(posedge clk);
        shadow[7:0] ^= {key_digit[0],key_digit[1],key_digit[2],key_digit[3],
                        key_digit[4],key_digit[5],key_digit[6],key_digit[7]};
        assert_msg(debug_bus==shadow[7:0],"key failed");
        key_shadow = key_digit;
        key_digit  = 0;
        repeat(2) @(posedge clk);
        key_digit = key_shadow<<1;
        repeat(2) @(posedge clk);
    end

    $display("PASS");
    $finish;
end

jtframe_debug_bus uut(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .shift      ( shift     ),
    .ctrl       ( ctrl      ),
    .inc        ( {1'b0,inc}),
    .dec        ( {1'b0,dec}),
    .key_digit  ( key_digit ),

    .debug_bus  ( debug_bus )
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( cen_h         ),
    .lhbl       ( lhbl          ),
    .lvbl       ( lvbl          ),
    .framecnt   (               )
);

endmodule