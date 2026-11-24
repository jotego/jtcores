`timescale 1ns/1ps

// Two jtshouse_cenloop instances leave reset at different times. Their CPU
// clock enables must follow the same pattern counted from the reset release,
// so the main, sub, MCU and sound CPUs start with the same phases every run.
module test;

`include "test_tasks.vh"

localparam PULSES=40;

reg  clk=0, rst_a=1, rst_b=1;
wire [4:0] cen_a, cen_b;
integer cnt_a=0, cnt_b=0, na=0, nb=0, k;
integer seq_a[0:PULSES-1], seq_b[0:PULSES-1];

always #10.17 clk=~clk;

always @(posedge clk) begin
    if( rst_a ) cnt_a <= 0; else cnt_a <= cnt_a+1;
    if( rst_b ) cnt_b <= 0; else cnt_b <= cnt_b+1;
    if( !rst_a && |cen_a && na<PULSES ) begin seq_a[na] = cnt_a*32+cen_a; na = na+1; end
    if( !rst_b && |cen_b && nb<PULSES ) begin seq_b[nb] = cnt_b*32+cen_b; nb = nb+1; end
end

initial begin
    repeat(37) @(posedge clk); rst_a <= 0;
    repeat(43) @(posedge clk); rst_b <= 0;
    wait( na==PULSES && nb==PULSES );
    for( k=0; k<PULSES; k=k+1 )
        assert_msg( seq_a[k]==seq_b[k], "CPU clock enables depend on the reset release time" );
    pass();
end

jtshouse_cenloop uut_a(
    .rst        ( rst_a     ),
    .clk        ( clk       ),
    .busy       ( 3'd0      ),
    .cen_main   ( cen_a[0]  ),
    .cen_sub    ( cen_a[1]  ),
    .cen_mcu    ( cen_a[2]  ),
    .cen_sndq   ( cen_a[3]  ),
    .snd_sel    (           ),
    .cen_snd    ( cen_a[4]  ),
    .fave       (           ),
    .fworst     (           )
);

jtshouse_cenloop uut_b(
    .rst        ( rst_b     ),
    .clk        ( clk       ),
    .busy       ( 3'd0      ),
    .cen_main   ( cen_b[0]  ),
    .cen_sub    ( cen_b[1]  ),
    .cen_mcu    ( cen_b[2]  ),
    .cen_sndq   ( cen_b[3]  ),
    .snd_sel    (           ),
    .cen_snd    ( cen_b[4]  ),
    .fave       (           ),
    .fworst     (           )
);

initial begin
    #200000 fail();
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

endmodule
