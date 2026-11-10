`include "fixtures.vh"
`timescale 1ns/1ps

module test;
reg clk=0, rst=1, rv=0;
always #10.417 clk=~clk;

integer acc=0;
reg [1:0] div=0;
reg cen20=0, cen10=0, cen5=0;
reg cen10_d=0, sample_cen=0;
always @(posedge clk) begin
    cen20 <= 0;
    cen10 <= 0;
    cen5  <= 0;
    if( acc+21>=50 ) begin
        acc <= acc+21-50;
        cen20 <= 1;
        div <= div+2'd1;
        cen10 <= div[0];
        cen5 <= div==3;
    end else acc <= acc+21;
    cen10_d <= cen10;
    sample_cen <= cen10_d;
end

wire [7:0] tprom_addr, h_raw, h, v;
wire [3:0] tprom_data;
wire hb, h20, vb, hbd_n, ai_n, bi_n, initeo, sy_n, hs, vs, lhbl, lvbl;
wire hs_out, vs_out;

jtframe_prom #(.DW(4),.AW(8),.SIMFILE(`PROM)) u_prom(
    .clk(clk), .cen(1'b1), .data(4'd0), .rd_addr(tprom_addr),
    .wr_addr(8'd0), .we(1'b0), .q(tprom_data)
);

jtpopeye_timing u_timing(
    .rst(rst), .clk(clk), .cen5(cen5), .cen10(cen10), .rv(rv),
    .tprom_addr(tprom_addr), .tprom_data(tprom_data),
    .h_raw(h_raw), .hb(hb), .h(h), .h20(h20), .v(v), .vb(vb),
    .hbd_n(hbd_n), .ai_n(ai_n), .bi_n(bi_n), .initeo(initeo),
    .sy_n(sy_n), .vtick(), .vcnt(), .vlatch(), .vhalf(),
    .hs(hs), .vs(vs), .lhbl(lhbl), .lvbl(lvbl)
);

jtframe_resync u_resync(
    .clk(clk), .pxl_cen(sample_cen), .hs_in(hs), .vs_in(vs),
    .LVBL(lvbl), .LHBL(lhbl), .hoffset(4'd0), .voffset(4'd0),
    .hs_out(hs_out), .vs_out(vs_out)
);

integer n_in=0, n_out=0, matched=0, errors=0, d;
integer sample_count=0, last_hs_sample=0, last_ohs_sample=0;
integer last_input_edge=0, last_output_edge=0, last_input_phase=0;
reg hs_l=0, vs_l=0, ohs_l=0, ovs_l=0, lvbl_l=0;

always @(posedge clk) if( !rst && sample_cen ) begin
    sample_count = sample_count+1;
    hs_l <= hs; vs_l <= vs;
    ohs_l <= hs_out; ovs_l <= vs_out; lvbl_l <= lvbl;
    if( lvbl && !lvbl_l && n_in>=2 && n_in<9 )
        $display("active field %0d begins %0d pixels after VS, phase %0d, vcnt %0d vhalf %0d", n_in-1,
                 sample_count-last_input_edge, sample_count-last_hs_sample, u_timing.vcnt, u_timing.vhalf);
    if( hs && !hs_l ) last_hs_sample=sample_count;
    if( hs_out && !ohs_l ) last_ohs_sample=sample_count;
    if( vs && !vs_l ) begin
        if( n_in>=2 ) begin
            d = sample_count-last_input_edge;
            if( d!=164160 ) errors=errors+1;
            d = sample_count-last_hs_sample-last_input_phase;
            if( d!=320 && d!= -320 ) errors=errors+1;
            $display("native field %0d: %0d pixels, VS phase %0d", n_in,
                     sample_count-last_input_edge, sample_count-last_hs_sample);
        end
        last_input_phase=sample_count-last_hs_sample;
        last_input_edge=sample_count;
        n_in = n_in+1;
    end
    if( vs_out && !ovs_l ) begin
        if( n_out>=2 && n_in>=3 ) begin
            $display("framework field %0d: %0d pixels, VS phase %0d, lag %0d", n_out,
                     sample_count-last_output_edge, sample_count-last_ohs_sample,
                     sample_count-last_input_edge);
            if( sample_count-last_output_edge!=164160 ) errors=errors+1;
            if( sample_count-last_input_edge<0 || sample_count-last_input_edge>4 ) errors=errors+1;
            matched=matched+1;
        end
        last_output_edge=sample_count;
        n_out = n_out+1;
    end
end

initial begin
    // jtframe_resync has no reset on its field bit; model FPGA power-up.
    u_resync.field = 0;
    repeat(20) @(posedge clk);
    rst=0;
    wait( matched>=4 );
    if( errors==0 ) $display("PASS: native half-line phase survives jtframe_resync");
    else $display("FAIL: %0d resync phase errors",errors);
    $finish;
end

initial begin
    repeat(10000000) @(posedge clk);
    $display("FAIL: resync timeout, native=%0d framework=%0d",n_in,n_out);
    $finish;
end
endmodule
