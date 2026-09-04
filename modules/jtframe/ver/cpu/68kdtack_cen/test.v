module test;

wire [31:0] framecnt;
wire [15:0] fave, fworst, rec_fave;
wire        rst, clk, hs, DTACKn, pxl_cen,
            cpu_cen, cpu_cenb, eff_cen, eff_cenb,
            ref_cen, ref_cenb, bus_cs, rec_DTACKn, rec_bus_cs,
            wait2_DTACKn, wait3_DTACKn;
reg  [31:0] cpu_cen_count, cpu_cenb_count,
            eff_cen_count, eff_cenb_count,
            ref_cen_count, ref_cenb_count, missing_peak,
            scheduled_debt_count, replay_count;
reg  [ 4:0] den;
reg  [ 3:0] num;
reg         asn, bus_busy, rec_asn, rec_bus_busy, stats_clr,
            recovery_done, wait_asn, wait_test_done;
integer     errors;
integer     wait2_ticks, wait3_ticks;

`include "test_tasks.vh"

assign eff_cen  = uut_recovery.eff_cen;
assign eff_cenb = uut_recovery.eff_phase && !uut_recovery.eff_risefall;
assign bus_cs   = !asn;
assign rec_bus_cs = !rec_asn;

always @(posedge clk) begin
    if( rst || stats_clr ) begin
        cpu_cen_count  <= 0;
        cpu_cenb_count <= 0;
        eff_cen_count  <= 0;
        eff_cenb_count <= 0;
        ref_cen_count  <= 0;
        ref_cenb_count <= 0;
        missing_peak   <= 0;
        scheduled_debt_count <= 0;
        replay_count         <= 0;
    end else begin
        if( cpu_cen  ) cpu_cen_count  <= cpu_cen_count  + 1'd1;
        if( cpu_cenb ) cpu_cenb_count <= cpu_cenb_count + 1'd1;
        if( eff_cen  ) eff_cen_count  <= eff_cen_count  + 1'd1;
        if( eff_cenb ) eff_cenb_count <= eff_cenb_count + 1'd1;
        if( ref_cen  ) ref_cen_count  <= ref_cen_count  + 1'd1;
        if( ref_cenb ) ref_cenb_count <= ref_cenb_count + 1'd1;
        if( uut_recovery.delayed && uut_recovery.over )
            scheduled_debt_count <= scheduled_debt_count + 1'd1;
        if( uut_recovery.recover ) replay_count <= replay_count + 1'd1;
        if( uut_recovery.genblk1.missing > missing_peak )
            missing_peak <= uut_recovery.genblk1.missing;
    end
end

task clear_stats(); begin
    @(negedge clk);
    stats_clr = 1;
    @(negedge clk);
    stats_clr = 0;
end endtask

task realistic_bus_traffic(input integer transactions);
    integer k;
begin
    for( k=0; k<transactions; k=k+1 ) begin
        // A short SDRAM response followed by the small inter-cycle gap
        // produced by fx68k. Vary both lengths deterministically.
        @(negedge clk);
        rec_asn      = 0;
        rec_bus_busy = 1;
        repeat( 6 + k%5 ) @(posedge clk);
        @(negedge clk);
        rec_bus_busy = 0;
        while( rec_DTACKn ) @(posedge clk);
        @(negedge clk);
        rec_asn = 1;
        repeat( 2 + k%4 ) @(posedge clk);
    end
end endtask

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
    asn      = 1;
    bus_busy = 0;
    stats_clr = 1;
    errors   = 0;

    @(negedge rst);
    // 8MHz test
    // used in CPS1, sf, rastan
    num=1;
    den=5'd6;
    repeat (20) @(posedge hs);
    assert_msg(uut.fave>=16'h0799 && uut.fave<=16'h0800,
        "frequency must be 8MHz within counter resolution");
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
    assert_msg(uut.fave>=16'h0899 && uut.fave<=16'h0900,
        "frequency must be 9MHz within counter resolution");
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
    assert_msg(uut.fave>=16'h0999 && uut.fave<=16'h1000,
        "frequency must be 10MHz within counter resolution");
    repeat (120) begin
        random_asn_pulses();
        assert_msg(uut.fave<16'h1006,"frequency is over  10.06MHz");
        assert_msg(uut.fave>16'h994,"frequency is below 9.94MHz");
    end
    // 12MHz test
    num=4'd1;
    den=5'd4;
    repeat (40) @(posedge hs);
    assert_msg(uut.fave>=16'h1199 && uut.fave<=16'h1200,
        "frequency must be 12MHz within counter resolution");
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

    wait( recovery_done );
    wait( wait_test_done );
    pass();
end

initial begin
    wait_asn       = 1;
    wait_test_done = 0;

    @(negedge rst);
    repeat (8) @(posedge clk);
    @(negedge clk);
    wait_asn = 0;

    fork
        begin
            wait2_ticks = 0;
            while( wait2_DTACKn ) begin
                @(posedge clk);
                wait2_ticks = wait2_ticks + 1;
            end
        end
        begin
            wait3_ticks = 0;
            while( wait3_DTACKn ) begin
                @(posedge clk);
                wait3_ticks = wait3_ticks + 1;
            end
        end
    join

    $display("wait-state latency: wait2=%0d clocks wait3=%0d clocks",
        wait2_ticks, wait3_ticks);
    assert_msg(wait3_ticks>wait2_ticks,"wait3 must assert DTACKn later than wait2");
    wait_test_done = 1;
end

initial begin
    rec_asn       = 1;
    rec_bus_busy  = 0;
    recovery_done = 0;

    // Reproduce the sustained SDRAM traffic seen by Toki. Once traffic
    // stops, give the recovery engine enough time to drain all visible debt.
    // A correct implementation must then match the no-wait reference.
    @(negedge rst);
    repeat (32) @(posedge clk);
    clear_stats();
    realistic_bus_traffic(3000);
    repeat (10000) @(posedge clk);
    @(negedge clk);

    $display("recovery test: raw=%0d/%0d effective=%0d/%0d reference=%0d/%0d debt/replay=%0d/%0d peak=%0d fave=%h",
        cpu_cen_count, cpu_cenb_count,
        eff_cen_count, eff_cenb_count,
        ref_cen_count, ref_cenb_count,
        scheduled_debt_count, replay_count, missing_peak, rec_fave);

    if( cpu_cen_count>cpu_cenb_count+1 || cpu_cenb_count>cpu_cen_count+1 ) begin
        $display("Raw cpu_cen/cpu_cenb phase counts differ by more than one");
        errors = errors+1;
    end
    if( scheduled_debt_count != replay_count ||
        uut_recovery.genblk1.missing != 0 ) begin
        $display("Scheduled recovery debt was not replayed exactly");
        errors = errors+1;
    end
    if( eff_cen_count>eff_cenb_count+1 ||
        eff_cenb_count>eff_cen_count+1 ) begin
        $display("Effective cpu_cen/cpu_cenb phase counts differ by more than one");
        errors = errors+1;
    end
    if( eff_cen_count+eff_cenb_count >
            ref_cen_count+ref_cenb_count+1 ||
        ref_cen_count+ref_cenb_count >
            eff_cen_count+eff_cenb_count+1 ) begin
        $display("Aligned effective phases do not match the no-wait schedule");
        errors = errors+1;
    end
    if( rec_fave<16'h0995 || rec_fave>16'h1005 ) begin
        $display("Aligned recovery frequency is not 10 MHz");
        errors = errors+1;
    end
    if( cpu_cen_count+cpu_cenb_count >
            ref_cen_count+ref_cenb_count+replay_count+1 ||
        ref_cen_count+ref_cenb_count+replay_count >
            cpu_cen_count+cpu_cenb_count+1 ) begin
        $display("Delivered phases do not equal scheduled plus replayed phases");
        errors = errors+1;
    end
    if( errors!=0 ) fail();
    recovery_done = 1;
end

jtframe_68kdtack_cen #(
    .RECOVERY   ( 1      ),
    .MFREQ      ( 48_000 )
) uut(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    (           ),
    .cpu_cenb   (           ),
    .bus_cs     ( bus_cs    ),
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

jtframe_68kdtack_cen #(
    .RECOVERY   ( 1      ),
    .MFREQ      ( 48_000 )
) uut_recovery(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .cpu_cen    ( cpu_cen      ),
    .cpu_cenb   ( cpu_cenb     ),
    .bus_cs     ( rec_bus_cs   ),
    .bus_busy   ( rec_bus_busy ),
    .bus_legit  ( 1'b0         ),
    .bus_ack    ( 1'b0         ),
    .ASn        ( rec_asn      ),
    .DSn        ( {2{rec_asn}} ),
    .num        ( 4'd5         ),
    .den        ( 5'd24        ),
    .wait2      ( 1'b0         ),
    .wait3      ( 1'b0         ),
    .DTACKn     ( rec_DTACKn   ),
    .fave       ( rec_fave     ),
    .fworst     (              )
);

jtframe_68kdtack_cen #(
    .RECOVERY   ( 0      ),
    .MFREQ      ( 48_000 )
) uut_ref(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( ref_cen   ),
    .cpu_cenb   ( ref_cenb  ),
    .bus_cs     ( 1'b0      ),
    .bus_busy   ( 1'b0      ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( 1'b1      ),
    .DSn        ( 2'b11     ),
    .num        ( 4'd5      ),
    .den        ( 5'd24     ),
    .DTACKn     (           ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
);

jtframe_68kdtack_cen #(.RECOVERY(0)) uut_wait2(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    (               ),
    .cpu_cenb   (               ),
    .bus_cs     ( 1'b0          ),
    .bus_busy   ( 1'b0          ),
    .bus_legit  ( 1'b0          ),
    .bus_ack    ( 1'b0          ),
    .ASn        ( wait_asn      ),
    .DSn        ( {2{wait_asn}} ),
    .num        ( 4'd1          ),
    .den        ( 5'd4          ),
    .wait2      ( 1'b1          ),
    .wait3      ( 1'b0          ),
    .DTACKn     ( wait2_DTACKn  ),
    .fave       (               ),
    .fworst     (               )
);

jtframe_68kdtack_cen #(.RECOVERY(0)) uut_wait3(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    (               ),
    .cpu_cenb   (               ),
    .bus_cs     ( 1'b0          ),
    .bus_busy   ( 1'b0          ),
    .bus_legit  ( 1'b0          ),
    .bus_ack    ( 1'b0          ),
    .ASn        ( wait_asn      ),
    .DSn        ( {2{wait_asn}} ),
    .num        ( 4'd1          ),
    .den        ( 5'd4          ),
    .wait2      ( 1'b0          ),
    .wait3      ( 1'b1          ),
    .DTACKn     ( wait3_DTACKn  ),
    .fave       (               ),
    .fworst     (               )
);

jtframe_test_clocks #(
    .TIMEOUT    ( 120_000_000 ),
    .MAXFRAMES  ( 6           )
) clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .framecnt   ( framecnt      )
);

endmodule // test
