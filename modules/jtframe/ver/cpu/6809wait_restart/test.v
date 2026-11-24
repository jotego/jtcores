`timescale 1ns/1ps

// Two jtframe_6809wait instances leave reset at different times while cen
// keeps running. Their E and Q pulses must follow the same pattern counted
// from the reset release, so the CPU starts with the same bus phase every run.
module test;

`include "test_tasks.vh"

localparam PULSES=24;

reg  clk=0, rstn_a=0, rstn_b=0, cr_a=0, cr_b=0, rl_a=0, rl_b=0;
reg  [1:0] div=0, div_a=0, div_b=0;
wire e_a, q_a, e_b, q_b;
wire cen_a = cr_a & ~(rstn_a & ~rl_a);  // a pulse set before the restart is dropped
wire cen_b = cr_b & ~(rstn_b & ~rl_b);
integer cnt_a=0, cnt_b=0, na=0, nb=0, k;
integer seq_a[0:PULSES-1], seq_b[0:PULSES-1];

always #10 clk=~clk;

// cen every 4 clk cycles. It runs during reset and its phase restarts when
// the reset is released, as jtframe_gated_cen does
always @(posedge clk) begin
    div  <= div+2'd1;
    rl_a <= rstn_a;
    rl_b <= rstn_b;
    div_a <= rstn_a ? div_a+2'd1 : 2'd0;
    div_b <= rstn_b ? div_b+2'd1 : 2'd0;
    cr_a  <= rstn_a ? div_a==3 : div==3;
    cr_b  <= rstn_b ? div_b==3 : div==3;
end

always @(posedge clk) begin
    if( !rstn_a ) cnt_a <= 0; else cnt_a <= cnt_a+1;
    if( !rstn_b ) cnt_b <= 0; else cnt_b <= cnt_b+1;
    if( rstn_a && (e_a||q_a) && na<PULSES ) begin seq_a[na] = cnt_a*2+q_a; na = na+1; end
    if( rstn_b && (e_b||q_b) && nb<PULSES ) begin seq_b[nb] = cnt_b*2+q_b; nb = nb+1; end
end

initial begin
    repeat(40) @(posedge clk); rstn_a <= 1;
    repeat(41) @(posedge clk); rstn_b <= 1;   // not a multiple of the E/Q period
    wait( na==PULSES && nb==PULSES );
    for( k=0; k<PULSES; k=k+1 )
        assert_msg( seq_a[k]==seq_b[k], "E/Q phase depends on the reset release time" );
    pass();
end

jtframe_6809wait #(.RECOVERY(0)) uut_a(
    .rstn       ( rstn_a    ),
    .clk        ( clk       ),
    .cen        ( cen_a     ),
    .cpu_cen    (           ),
    .dev_busy   ( 1'b0      ),
    .rom_cs     ( 1'b0      ),
    .rom_ok     ( 1'b1      ),
    .cen_E      ( e_a       ),
    .cen_Q      ( q_a       )
);

jtframe_6809wait #(.RECOVERY(0)) uut_b(
    .rstn       ( rstn_b    ),
    .clk        ( clk       ),
    .cen        ( cen_b     ),
    .cpu_cen    (           ),
    .dev_busy   ( 1'b0      ),
    .rom_cs     ( 1'b0      ),
    .rom_ok     ( 1'b1      ),
    .cen_E      ( e_b       ),
    .cen_Q      ( q_b       )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

endmodule
