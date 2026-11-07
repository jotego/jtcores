module test;

wire [31:0] framecnt;
wire [15:0] fave, fworst, rec_fave;
wire        rst, clk, hs, DTACKn, pxl_cen,
            cpu_cen, cpu_cenb,
            ref_cen, ref_cenb, bus_cs, rec_DTACKn, rec_bus_cs,
            wait2_DTACKn, wait3_DTACKn;
reg  [31:0] cpu_cen_count, cpu_cenb_count,
            ref_cen_count, ref_cenb_count, missing_peak,
            scheduled_debt_count, replay_count;
reg  [ 4:0] den;
reg  [ 3:0] num;
reg         asn, bus_busy, rec_asn, rec_bus_busy, stats_clr,
            recovery_done, wait_asn, wait_test_done, rec_legit, rec_ack;
reg phase_seen, last_phi1;
wire [5:0] qualification_done;
integer     errors;
integer     wait2_ticks, wait3_ticks;

`include "test_tasks.vh"

assign bus_cs   = !asn;
assign rec_bus_cs = !rec_asn;

always @(posedge clk) begin
    if( rst || stats_clr ) begin
        cpu_cen_count  <= 0;
        cpu_cenb_count <= 0;
        ref_cen_count  <= 0;
        ref_cenb_count <= 0;
        missing_peak   <= 0;
        scheduled_debt_count <= 0;
        replay_count         <= 0;
        phase_seen <= 0;
        last_phi1 <= 0;
    end else begin
        assert_msg(!(cpu_cen && cpu_cenb), "CPU phases must never overlap");
        if(cpu_cen || cpu_cenb) begin
            if(phase_seen) assert_msg(cpu_cen != last_phi1,"Delivered phases must alternate across holds/recovery");
            phase_seen <= 1;
            last_phi1 <= cpu_cen;
        end
        if(rec_legit || rec_ack) begin
            assert_msg(!uut_recovery.recover,"No debt replay during legitimate wait or bus ownership");
            assert_msg(!uut_recovery.hold_cpu,"Do not hold CPU phases during legitimate wait or bus ownership");
        end
        if( cpu_cen  ) cpu_cen_count  <= cpu_cen_count  + 1'd1;
        if( cpu_cenb ) cpu_cenb_count <= cpu_cenb_count + 1'd1;
        if( ref_cen  ) ref_cen_count  <= ref_cen_count  + 1'd1;
        if( ref_cenb ) ref_cenb_count <= ref_cenb_count + 1'd1;
        if( uut_recovery.hold_cpu && uut_recovery.over )
            scheduled_debt_count <= scheduled_debt_count + 1'd1;
        if( uut_recovery.recover ) replay_count <= replay_count + 1'd1;
        if( uut_recovery.missing > missing_peak )
            missing_peak <= uut_recovery.missing;
    end
end

task clear_stats(); begin
    @(negedge clk);
    stats_clr = 1;
    @(negedge clk);
    stats_clr = 0;
end endtask

task next_phi1; begin
    @(posedge clk);
    while(!cpu_cen) @(posedge clk);
    @(negedge clk);
end endtask

task close_bus; begin
    // fx68k samples DTACK on Phi2, then advances the bus on Phi1.
    @(posedge clk);
    while(!cpu_cenb || rec_DTACKn) @(posedge clk);
    next_phi1();
    rec_asn=1;
end endtask

task realistic_bus_traffic(input integer transactions);
    integer k;
begin
    for(k=0;k<transactions;k=k+1) begin
        next_phi1();
        rec_asn=0;
        rec_bus_busy=1;
        repeat(6+k%17) @(negedge clk);
        rec_bus_busy=0;
        close_bus();
        // Leave internal execution time between accesses so the requested
        // frequency is physically attainable with these response latencies.
        repeat(4) next_phi1();
    end
end endtask

task exclusion_test;
    integer held_debt, phase_start;
begin
    next_phi1(); rec_asn=0; rec_bus_busy=1;
    // Accumulate genuine withheld phases before exercising both exclusions.
    repeat(100) @(negedge clk);
    assert_msg(uut_recovery.missing>0,"Artificial memory stall must create debt");
    rec_legit=1;
    held_debt=uut_recovery.missing;
    phase_start=cpu_cen_count+cpu_cenb_count;
    repeat(80) @(negedge clk);
    assert_msg(uut_recovery.missing==held_debt,"Legitimate waits neither charge nor drain debt");
    assert_msg(cpu_cen_count+cpu_cenb_count>phase_start,"CPU phases continue during legitimate board wait");
    // Bus ownership excludes replay even when memory becomes ready.
    rec_ack=1; rec_legit=0; rec_bus_busy=0;
    phase_start=cpu_cen_count+cpu_cenb_count;
    repeat(80) @(negedge clk);
    assert_msg(uut_recovery.missing==held_debt,"Bus ownership neither charges nor drains debt");
    assert_msg(cpu_cen_count+cpu_cenb_count>phase_start,"CPU phases continue for arbitration");
    close_bus();
    rec_ack=0;
    repeat(400) @(negedge clk);
    assert_msg(uut_recovery.missing==0,"Debt drains after board wait and arbitration end");
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
    wait( &qualification_done );
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
    rec_legit=0; rec_ack=0;
    recovery_done = 0;

    // Reproduce the sustained SDRAM traffic seen by Toki. Once traffic
    // stops, give the recovery engine enough time to drain all visible debt.
    // A correct implementation must then match the no-wait reference.
    @(negedge rst);
    repeat (32) @(posedge clk);
    clear_stats();
    exclusion_test();
    realistic_bus_traffic(3000);
    repeat (10000) @(posedge clk);
    @(negedge clk);

    $display("recovery test: delivered=%0d/%0d reference=%0d/%0d withheld/replay=%0d/%0d peak=%0d fave=%h",
        cpu_cen_count, cpu_cenb_count,
        ref_cen_count, ref_cenb_count,
        scheduled_debt_count, replay_count, missing_peak, rec_fave);

    if( cpu_cen_count>cpu_cenb_count+1 || cpu_cenb_count>cpu_cen_count+1 ) begin
        $display("Raw cpu_cen/cpu_cenb phase counts differ by more than one");
        errors = errors+1;
    end
    if( scheduled_debt_count != replay_count ||
        uut_recovery.missing != 0 ) begin
        $display("Scheduled recovery debt was not replayed exactly");
        errors = errors+1;
    end
    if(cpu_cen_count+cpu_cenb_count != ref_cen_count+ref_cenb_count) begin
        $display("Debt-free delivered phases do not match the nominal schedule");
        errors=errors+1;
    end
    if( rec_fave<16'h0995 || rec_fave>16'h1005 ) begin
        $display("Delivered recovery frequency is not 10 MHz");
        errors = errors+1;
    end
    if(cpu_cen_count+cpu_cenb_count+scheduled_debt_count !=
            ref_cen_count+ref_cenb_count+replay_count) begin
        $display("Delivered phases do not equal scheduled minus withheld plus replayed phases");
        errors=errors+1;
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
    .bus_legit  ( rec_legit    ),
    .bus_ack    ( rec_ack      ),
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

genvar cfg;
generate for(cfg=0;cfg<6;cfg=cfg+1) begin: qualification
    dtack_wait_check #(.WAIT1(cfg>=3),.EXTRA(cfg>=3 ? cfg-3 : cfg)) check_wait(
        .clk(clk), .rst(rst), .done(qualification_done[cfg])
    );
end endgenerate

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

// Qualify WAIT1 and both configured extra waits using delivered CPU phases,
// then check that a late response can wake the held DTACK-sampling Phi2.
module dtack_wait_check #(parameter WAIT1=0, EXTRA=0)(
    input clk, rst,
    output reg done=0
);
reg asn=1, busy=0;
wire cen, cenb, dtackn;
wire wait2, wait3, cs;
integer phi1_count, debt_before, idle_count;
localparam EXPECT_PHI1 = WAIT1 ? (EXTRA==2 ? 3 : 2) : EXTRA;
assign wait2=EXTRA==1;
assign wait3=EXTRA==2;
assign cs=!asn;
jtframe_68kdtack_cen #(.WAIT1(WAIT1),.MFREQ(48000)) uut(
    .rst(rst), .clk(clk), .cpu_cen(cen), .cpu_cenb(cenb),
    .bus_cs(cs), .bus_busy(busy), .bus_legit(1'b0), .bus_ack(1'b0),
    .ASn(asn), .DSn({2{asn}}), .num(4'd1), .den(5'd4),
    .wait2(wait2), .wait3(wait3), .DTACKn(dtackn), .fave(), .fworst()
);
`include "test_tasks.vh"
// Check replay exclusion continuously, including a new access started with
// debt remaining from the preceding artificial stall.
always @(posedge clk) if(!rst && !asn) begin
    if(uut.waitsh!=0 || (WAIT1!=0 && !uut.ack_armed)) begin
        assert_msg(!uut.recover,"Configured board waits must not spend recovery debt");
        assert_msg(!uut.hold_cpu,"Configured board waits must continue nominal phases");
    end
end
task start_bus;
begin
    @(posedge clk); while(!cen) @(posedge clk);
    @(negedge clk); asn=0;
end
endtask
task close_bus;
begin
    @(posedge clk); while(!cenb || dtackn) @(posedge clk);
    @(posedge clk); while(!cen) @(posedge clk);
    @(negedge clk); asn=1;
end
endtask
initial begin
    @(negedge rst);
    repeat(8) @(negedge clk);
    start_bus();
    phi1_count=0;
    while(dtackn) begin
        @(posedge clk);
        if(cen) phi1_count=phi1_count+1;
        @(negedge clk);
    end
    $display("WAIT1=%0d EXTRA=%0d ready acknowledgement after %0d Phi1 events",WAIT1,EXTRA,phi1_count);
    assert_msg(phi1_count==EXPECT_PHI1,"Ready memory preserves deliberate wait qualification");
    assert_msg(uut.missing==0,"Ready memory must not acquire recovery debt");
    close_bus();
    start_bus(); busy=1;
    // Long enough to finish all configured waits and hold an actual Phi2.
    repeat(100) @(negedge clk);
    assert_msg(uut.hold_cpu && !cen && !cenb,"Late memory response holds both CPU enables");
    assert_msg(uut.missing>0,"Held nominal phases create recovery debt");
    busy=0;
    // DTACK must become ready without requiring a delivered Phi1.
    idle_count=0;
    while(dtackn && idle_count<5) begin
        @(posedge clk);
        assert_msg(!cen,"DTACK wakeup must not require a Phi1 while held");
        @(negedge clk);
        idle_count=idle_count+1;
    end
    assert_msg(!dtackn,"Memory readiness releases held Phi2 on master-clock edges");
    close_bus();
    start_bus(); busy=1;
    debt_before=uut.missing;
    assert_msg(debt_before>0,"New configured wait tested with outstanding debt");
    while(!uut.ack_ready) @(negedge clk);
    if(EXTRA!=0 || WAIT1!=0)
        assert_msg(uut.missing==debt_before,"Configured wait neither charges nor drains existing debt");
    busy=0; close_bus();
    // Idle wait inputs still describe the prior access. Clear AS so no CPU
    // delay exists, and give the faster schedule room to drain all debt.
    repeat(1000) @(negedge clk);
    assert_msg(uut.missing==0,"Recovery drains after wait-qualified transfers");
    done=1;
end
endmodule
