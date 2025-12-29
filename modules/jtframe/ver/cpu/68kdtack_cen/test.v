module test;

`include "test_tasks.vh"

wire rst, clk, hs, DTACKn, pxl_cen;
reg  [ 3:0] num;
reg  [ 4:0] den;
wire [15:0] fave, fworst;
wire [31:0] framecnt;
reg         asn, bus_busy;

task random_asn_pulses(); begin
    repeat (800) begin
        @(negedge clk);
        if( !DTACKn )
            asn = 1;
        else if(asn) begin
            asn = $random;
            if(!asn && ($random%100)>15) begin
                bus_busy = 1;
                if(bus_busy) begin
                    repeat( $random % 12 ) @(posedge clk);
                end
                bus_busy=0;
            end
            repeat( $random % 7 ) begin
                @(posedge clk);
                if(!DTACKn) asn=1;
            end
        end
        while( !asn && DTACKn ) @(posedge clk);
        asn = 1;
    end
    @(posedge hs);
end endtask

initial begin
    asn=1;
    bus_busy=0;
    // 8MHz test
    // used in CPS1, sf, rastan
    num=1;
    den=5'd6;
    repeat (20) @(posedge hs);
    assert_msg(uut.fave==16'h800,"frequency must be 8MHz sharp");
    repeat (120) begin
        random_asn_pulses();
        assert_msg(uut.fave<16'h804,"frequency is over  8.04MHz");
        assert_msg(uut.fave>16'h796,"frequency is below 7.96MHz");
    end
    // 9MHz test
    // used in twin16 (with different PLL, resulting a bit over 9MHz)
    num=4'd3;
    den=5'd16;
    repeat (40) @(posedge hs);
    assert_msg(uut.fave==16'h0900,"frequency must be 9.00MHz sharp");
    repeat (120) begin
        random_asn_pulses();
        assert_msg(uut.fave<16'h0905,"frequency is over 100.5%%");
        assert_msg(uut.fave>16'h895,"frequency is below 99.5%%");
    end
    // 10MHz test
    // used in Toki, CPS1 (turbo)
    num=4'd5;
    den=5'd24;
    repeat (40) @(posedge hs);
    assert_msg(uut.fave==16'h1000,"frequency must be 10MHz sharp");
    repeat (120) begin
        random_asn_pulses();
        assert_msg(uut.fave<16'h1006,"frequency is over  10.06MHz");
        assert_msg(uut.fave>16'h994,"frequency is below 9.94MHz");
    end
    // 12MHz test
    num=4'd1;
    den=5'd4;
    repeat (40) @(posedge hs);
    assert_msg(uut.fave==16'h1200,"frequency must be 12MHz sharp");
    repeat (120) begin
        random_asn_pulses();
        assert_msg(uut.fave<16'h1208,"frequency is over  12.08MHz");
        assert_msg(uut.fave>16'h1192,"frequency is below 11.92MHz");
    end
    // 16MHz test
    // riders, xmen, rungun
    num=4'd1;
    den=5'd3;
    repeat (60) @(posedge hs);
    assert_msg(uut.fave>=16'h1599&&uut.fave<=16'h1601,"frequency must be 16MHz sharp");
    repeat (120) begin
        random_asn_pulses();
        assert_msg(uut.fave<16'h1608,"frequency too fast +0.5%%");
        assert_msg(uut.fave>16'h1592,"frequency too slow -0.5%%");
    end
    pass();
end

jtframe_68kdtack_cen #(.RECOVERY(1),.MFREQ(48000))uut(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    (           ),
    .cpu_cenb   (           ),
    .bus_cs     ( bus_busy  ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( asn       ),  // DTACKn set low at the next cpu_cen after ASn goes low
    .DSn        ( {2{asn}}  ),  // If DSn goes high, DTACKn is reset high
    .num        ( num       ),  // numerator
    .den        ( den       ),  // denominator
    .wait2      ( 1'b0      ), // high for 2 wait states
    .wait3      ( 1'b0      ), // high for 3 wait states

    .DTACKn     ( DTACKn    ),
    .fave       ( fave      ), // average cpu_cen frequency in kHz
    .fworst     ( fworst    )  // average cpu_cen frequency in kHz
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .framecnt   ( framecnt      )
);

endmodule // test
