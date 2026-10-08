module test;

wire [9:0] raw_key_joy1, raw_key_joy2, raw_key_joy3, raw_key_joy4;
wire       ps2_kbd_clk=0, ps2_kbd_data=0;
wire [7:0] key_digit;
wire [3:0] key_start, key_coin;
wire       key_reset, key_pause, key_test, key_tilt,
           key_shift, key_ctrl,  key_alt;

initial begin
    // instantiation only
    $display("PASS");
end


jtframe_keyboard uut(
    .clk         ( clk_sys       ),
    .rst         ( rst           ),
    // ps2 interface
    .ps2_clk     ( ps2_kbd_clk   ),
    .ps2_data    ( ps2_kbd_data  ),
    // decoded keys
    .joy1        ( raw_key_joy1  ),
    .joy2        ( raw_key_joy2  ),
    .joy3        ( raw_key_joy3  ),
    .joy4        ( raw_key_joy4  ),
    .start       ( key_start     ),
    .coin        ( key_coin      ),
    .reset       ( key_reset     ),
    .test        ( key_test      ),
    .pause       ( key_pause     ),
    .service     ( key_service   ),
    .tilt        ( key_tilt      ),
    .digit       ( key_digit     ),

    .shift       ( key_shift     ),
    .ctrl        ( key_ctrl      ),
    .alt         ( key_alt       )
);

endmodule