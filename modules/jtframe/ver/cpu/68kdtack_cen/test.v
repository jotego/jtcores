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
    num=1;
    den=5'd6;
    // 8MHz test
    repeat (20) @(posedge hs);
    assert_msg(uut.fave==16'h800,"frequency must be 8MHz sharp");
    repeat (120) begin
        random_asn_pulses();
        assert_msg(uut.fave<16'h808,"frequency is over  8.08MHz");
        assert_msg(uut.fave>16'h792,"frequency is below 7.92MHz");
    end
    // 10MHz test
    num=4'd5;
    den=5'd24;
    repeat (40) @(posedge hs);
    assert_msg(uut.fave==16'h1000,"frequency must be 10MHz sharp");
    repeat (120) begin
        random_asn_pulses();
        assert_msg(uut.fave<16'h1011,"frequency is over  10.11MHz");
        assert_msg(uut.fave>16'h990,"frequency is below 9.90MHz");
    end
    // 12MHz test
    num=4'd1;
    den=5'd4;
    repeat (40) @(posedge hs);
    assert_msg(uut.fave==16'h1200,"frequency must be 12MHz sharp");
    repeat (120) begin
        random_asn_pulses();
        assert_msg(uut.fave<16'h1213,"frequency is over  12.13MHz");
        assert_msg(uut.fave>16'h1188,"frequency is below 11.88MHz");
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
