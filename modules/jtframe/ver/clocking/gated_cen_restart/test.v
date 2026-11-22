`timescale 1ns/1ps

// Two jtframe_gated_cen instances leave reset at different times. Their cen
// pulses must follow the same pattern counted from the reset release.
module test;

`include "test_tasks.vh"

localparam PULSES=40;

reg clk=0, rst_a=1, rst_b=1;
wire [1:0] cen_a, cen_b;
integer cnt_a=0, cnt_b=0, na=0, nb=0, k;
integer seq_a[0:PULSES-1], seq_b[0:PULSES-1];

always #10.4 clk=~clk;

always @(posedge clk) begin
    if( rst_a ) cnt_a <= 0; else cnt_a <= cnt_a+1;
    if( rst_b ) cnt_b <= 0; else cnt_b <= cnt_b+1;
    if( !rst_a && cen_a[0] && na<PULSES ) begin seq_a[na] = cnt_a; na = na+1; end
    if( !rst_b && cen_b[0] && nb<PULSES ) begin seq_b[nb] = cnt_b; nb = nb+1; end
end

initial begin
    repeat(37)  @(posedge clk); rst_a <= 0;
    repeat(254) @(posedge clk); rst_b <= 0;
    wait( na==PULSES && nb==PULSES );
    for( k=0; k<PULSES; k=k+1 )
        assert_msg( seq_a[k]==seq_b[k], "cen pattern depends on the reset release time" );
    pass();
end

// a fractional divider, so a free-running phase would show
jtframe_gated_cen #(.W(2),.NUM(9721),.DEN(65177),.MFREQ(48000)) uut_a(
    .rst    ( rst_a     ),
    .clk    ( clk       ),
    .busy   ( 1'b0      ),
    .cen    ( cen_a     ),
    .fave   (           ),
    .fworst (           )
);

jtframe_gated_cen #(.W(2),.NUM(9721),.DEN(65177),.MFREQ(48000)) uut_b(
    .rst    ( rst_b     ),
    .clk    ( clk       ),
    .busy   ( 1'b0      ),
    .cen    ( cen_b     ),
    .fave   (           ),
    .fworst (           )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

endmodule
