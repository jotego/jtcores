`timescale 1ns / 1ps

module test;

wire clk, boot_rst;
reg rst=1, cen=1, zero=1;
reg [9:0] value_A=0;
reg [7:0] value_B=0;
reg load_A=0, load_B=0, clr_flag_A=0, clr_flag_B=0;
reg enable_irq_A=0, enable_irq_B=0;
wire flag_A, flag_B, overflow_A, irq_n;
integer errors=0, a_overflows=0;
integer n, events, previous, first, old_overflows;

task tick;
begin
    @(posedge clk);
    #1;
    @(negedge clk);
end
endtask

task ticks(input integer count);
begin
    repeat(count) tick();
end
endtask

task check(input bit condition, input string message);
begin
    if(!condition) begin
        $display("FAIL: %s (A=%b B=%b IRQ_n=%b)",message,flag_A,flag_B,irq_n);
        errors=errors+1;
    end
end
endtask

task flags(input [1:0] expected, input string message);
begin
    check({flag_B,flag_A}===expected,message);
    check(irq_n===(expected==0),{message," IRQ"});
end
endtask

task reset_timers;
begin
    rst=1;
    cen=1;
    zero=1;
    load_A=0;
    load_B=0;
    clr_flag_A=0;
    clr_flag_B=0;
    enable_irq_A=0;
    enable_irq_B=0;
    ticks(2);
    rst=0;
    ticks(2);
    // Counter storage has no reset. Initialize through the public LOAD path
    // before testing new starts, so stale pre-reset counts are irrelevant.
    value_A=0;
    value_B=0;
    load_A=1;
    load_B=1;
    tick();
    load_A=0;
    load_B=0;
    clr_flag_A=1;
    clr_flag_B=1;
    ticks(2);
    clr_flag_A=0;
    clr_flag_B=0;
    flags(0,"reset clears flags");
end
endtask

// The overflow output serves CSM independently of the status/IRQ latch.
always @(posedge clk) begin
    if(rst) a_overflows=0;
    else if(cen && zero && load_A && overflow_A) a_overflows=a_overflows+1;
end

initial begin
    @(negedge boot_rst);
    @(negedge clk);

    reset_timers();
    value_A=10'd1020;
    load_A=1;
    tick(); // load on the rising LOAD edge
    ticks(12);
    check(a_overflows==3,"A keeps four-tick overflows with IRQEN clear");
    flags(0,"A disabled overflow does not latch flag");
    enable_irq_A=1;
    ticks(3);
    flags(0,"enabling A does not expose an old overflow");
    tick();
    flags(1,"new enabled A overflow latches flag");
    enable_irq_A=0;
    ticks(8);
    flags(1,"disabling A preserves latched flag and IRQ");
    clr_flag_A=1;
    tick();
    clr_flag_A=0;
    ticks(8);
    flags(0,"cleared disabled A remains clear while counting");
    enable_irq_A=1;
    ticks(4);
    flags(1,"reenabling A permits the next overflow");
    load_A=0;
    ticks(8);
    flags(1,"stopping A preserves its flag");
    clr_flag_A=1;
    tick();
    clr_flag_A=0;
    ticks(8);
    flags(0,"cleared stopped A stays clear");

    reset_timers();
    value_B=8'd254;
    load_B=1;
    tick();
    ticks(96);
    flags(0,"B disabled overflow does not latch flag");
    enable_irq_B=1;
    ticks(32);
    flags(2,"new enabled B overflow latches flag");
    enable_irq_B=0;
    ticks(32);
    flags(2,"disabling B preserves latched flag and IRQ");
    clr_flag_B=1;
    tick();
    clr_flag_B=0;
    ticks(64);
    flags(0,"cleared disabled B remains clear while counting");
    enable_irq_B=1;
    ticks(32);
    flags(2,"reenabling B permits the next overflow");
    load_B=0;
    ticks(32);
    flags(2,"stopping B preserves its flag");
    clr_flag_B=1;
    tick();
    clr_flag_B=0;
    ticks(32);
    flags(0,"cleared stopped B stays clear");

    reset_timers();
    value_A=10'd1023;
    value_B=8'd255;
    enable_irq_A=1;
    enable_irq_B=1;
    load_A=1;
    load_B=1;
    ticks(40);
    flags(3,"both independent sources assert IRQ");
    load_A=0;
    load_B=0;
    ticks(2);
    clr_flag_A=1;
    tick();
    clr_flag_A=0;
    flags(2,"clearing A leaves B and IRQ asserted");
    cen=0;
    zero=0;
    clr_flag_B=1;
    tick();
    clr_flag_B=0;
    flags(0,"clear works when CEN and ZERO are low");

    reset_timers();
    value_A=10'd1023;
    load_A=1;
    enable_irq_A=1;
    clr_flag_A=1;
    ticks(8);
    flags(0,"clear takes priority over continuous A overflow");
    clr_flag_A=0;
    tick();
    flags(1,"A overflow is accepted after clear ends");

    reset_timers();
    value_A=10'd1022;
    load_A=1;
    enable_irq_A=1;
    tick();
    cen=0;
    ticks(10);
    flags(0,"CEN pauses A");
    cen=1;
    zero=0;
    ticks(10);
    flags(0,"ZERO pauses A");
    zero=1;
    tick();
    flags(0,"A resumes with first count after pauses");
    cen=0;
    ticks(8);
    flags(0,"CEN pauses A just before overflow");
    cen=1;
    tick();
    flags(1,"A resumes at its expected overflow");

    reset_timers();
    value_A=10'd1020;
    load_A=1;
    tick();
    ticks(3);
    check(a_overflows==0,"A initial period waits four ticks");
    tick();
    check(a_overflows==1,"A first four-tick overflow");
    value_A=10'd1018; // takes effect on the next automatic reload
    ticks(4);
    check(a_overflows==2,"A current period retains old preload");
    ticks(5);
    check(a_overflows==2,"A next reload uses new six-tick preload");
    tick();
    check(a_overflows==3,"A new six-tick period overflows");
    old_overflows=a_overflows;
    load_A=0;
    ticks(20);
    check(a_overflows==old_overflows,"stopped A does not overflow");
    load_A=1;
    tick();
    ticks(5);
    check(a_overflows==old_overflows,"restarting A reloads full period");
    tick();
    check(a_overflows==old_overflows+1,"restarted A overflows on sixth tick");

    reset_timers();
    value_B=8'd254;
    enable_irq_B=1;
    load_B=1;
    tick();
    events=0;
    previous=0;
    first=0;
    for(n=1;n<=100;n=n+1) begin
        clr_flag_B=flag_B;
        tick();
        if(flag_B) begin
            if(events!=0) check(n-previous==32,"B reload period is 2*16 ticks");
            else first=n;
            previous=n;
            events=events+1;
        end
    end
    check(events==3,"B generates three reload overflows in 100 ticks");
    check(first>=17 && first<=32,"B first period includes free-running prescaler phase");

    reset_timers();
    value_B=8'd255;
    load_B=1;
    enable_irq_B=1;
    tick();
    first=0;
    while(!flag_B && first<32) begin
        tick();
        first=first+1;
    end
    check(first>4 && first<=16,"B unpaused prescaler reference interval");
    reset_timers();
    value_B=8'd255;
    load_B=1;
    enable_irq_B=1;
    tick();
    ticks(4);
    cen=0;
    ticks(64);
    flags(0,"CEN pauses B counter and prescaler");
    cen=1;
    zero=0;
    ticks(64);
    flags(0,"ZERO pauses B counter and prescaler");
    zero=1;
    ticks(first-5);
    flags(0,"B prescaler resumes without elapsed disabled ticks");
    tick();
    flags(2,"B overflows after remaining prescaler ticks");

    if(errors==0) $display("PASS: timer flag gating, sticky IRQ, reload periods and CEN");
    else $display("FAIL: %0d timer checks failed",errors);
    $finish;
end

jt51_timers uut(
    .rst          ( rst          ),
    .clk          ( clk          ),
    .cen          ( cen          ),
    .zero         ( zero         ),
    .value_A      ( value_A      ),
    .value_B      ( value_B      ),
    .load_A       ( load_A       ),
    .load_B       ( load_B       ),
    .clr_flag_A   ( clr_flag_A   ),
    .clr_flag_B   ( clr_flag_B   ),
    .enable_irq_A ( enable_irq_A ),
    .enable_irq_B ( enable_irq_B ),
    .flag_A       ( flag_A       ),
    .flag_B       ( flag_B       ),
    .overflow_A   ( overflow_A   ),
    .irq_n        ( irq_n        )
);

jtframe_test_clocks clocks(
    .rst      ( boot_rst ),
    .clk      ( clk      ),
    .pxl_cen  (          ),
    .lhbl     (          ),
    .lvbl     (          ),
    .hs       (          ),
    .vs       (          ),
    .h        (          ),
    .v        (          ),
    .framecnt (          )
);

endmodule
