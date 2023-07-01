`timescale 1ns / 1ps

module test;

reg clk, rst;

initial begin
    clk = 0;
    forever #5.55 clk = ~clk; // 90MHz
end

initial begin
    rst = 0;
    #10 rst = 1;
    #20 rst = 0;
end

integer scnt=0;
wire sample  = scnt==0;
wire sample2 = sample || scnt==1872;

always @(posedge clk) begin
    scnt <= scnt == 3746 ? 0 : scnt+1;
end

reg  signed [15:0] l_in, r_in;
wire signed [15:0] l_out, r_out;

reg l_s, r_s;
wire signed [16:0] step = 17'd100;

wire signed [16:0] next_up = { l_in[15], l_in } + step;
wire signed [16:0] next_dn = { l_in[15], l_in } - step;
wire ov = l_s ? next_up[16]^next_up[15] : next_dn[16]^next_dn[15];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        l_in <= 16'd0;
        l_s <= 0;
    end else if(sample) begin
        if( !ov ) begin
            l_in <= l_s ? next_up[15:0] : next_dn[15:0];
        end else begin
            l_s <= ~l_s;
            l_in <= !l_s ? next_up[15:0] : next_dn[15:0];
        end
    end
end

jtframe_uprate3_fir uut(
    .rst    ( rst    ),
    .clk    ( clk    ),
    .sample ( sample ),
    .l_in   ( l_in   ),
    .r_in   ( l_in   ),
    .l_out  ( l_out  ),
    .r_out  ( r_out  )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
    #22_000_000 $finish;
end

endmodule