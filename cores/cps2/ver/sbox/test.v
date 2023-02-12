module test(
    input  [ 7:0] din,
    input  [ 5:0] key,
    output [ 1:0] dout
);

    jtcps2_sbox #(
        .LUT( {
        2'd0, 2'd0, 2'd0, 2'd2, 2'd2, 2'd0, 2'd2, 2'd1,
        2'd1, 2'd1, 2'd3, 2'd1, 2'd3, 2'd2, 2'd1, 2'd3,
        2'd0, 2'd1, 2'd2, 2'd0, 2'd1, 2'd0, 2'd1, 2'd2,
        2'd0, 2'd2, 2'd0, 2'd1, 2'd2, 2'd1, 2'd3, 2'd2,
        2'd0, 2'd1, 2'd0, 2'd0, 2'd1, 2'd0, 2'd2, 2'd0,
        2'd2, 2'd0, 2'd3, 2'd2, 2'd1, 2'd0, 2'd1, 2'd0,
        2'd3, 2'd2, 2'd3, 2'd3, 2'd0, 2'd2, 2'd1, 2'd3,
        2'd2, 2'd2, 2'd0, 2'd1, 2'd1, 2'd3, 2'd0, 2'd3
        } ),
        .LOC( { 3'd7, 3'd6, 3'd3, 3'd2, 3'd1, 3'd0 } ),
        .OK ( 6'b11_1111 ))
    u_sbox_fn1_r1_2(
        .din ( din   ),
        .key ( key   ),
        .dout( dout  )
    );

endmodule