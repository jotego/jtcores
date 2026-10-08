module test;

wire        rst, clk;
reg  [ 1:0] raw=0;
reg         cnt_rst=1;
wire [ 1:0] joy;
wire [ 8:0] v;
wire [31:0] times_left, times_right;

reg signed [7:0] ana=0;

localparam FULL_RIGHT=127,
           RIGHT_75  = 48,
           RIGHT_50  = 32,
           RIGHT_25  = 16,
           STILL     = 0,
           LEFT_25   = -17,
           LEFT_50   = -33,
           LEFT_75   = -49,
           FULL_LEFT =-128;

count_times cnt1( cnt_rst, vs, joy[1], times_left);
count_times cnt2( cnt_rst, vs, joy[0], times_right);

jtframe_multiway_emu_analog uut(clk,v   [1:0],raw,ana,joy);

task rst_counters; begin
    cnt_rst=1;
    @(posedge clk);
    cnt_rst=0;
end endtask

function signed [31:0]abs_diff(input signed [31:0] a,b); begin
    abs_diff=a-b;
    if(abs_diff<0) abs_diff=-abs_diff;
end endfunction

task match( input [31:0] exp_left, exp_right ); begin
    if( abs_diff(times_left,exp_left)>1 || abs_diff(times_right,exp_right)>1 ) begin
        $display("Expected L,R=%0d,%0d but got %0d,%0d.\nFAIL",exp_left,exp_right, times_left,times_right);
        $finish;
    end
end endtask

initial begin
    repeat (40) @(posedge clk);
    rst_counters;
    raw=0;
    ana=STILL;
    repeat (60) @(posedge vs);
    match(0,0);

    rst_counters;
    raw=0;
    ana=RIGHT_25;
    repeat (60) @(posedge vs);
    match(0,15);

    rst_counters;
    raw=0;
    ana=RIGHT_50;
    repeat (60) @(posedge vs);
    match(0,30);

    rst_counters;
    raw=0;
    ana=RIGHT_75;
    repeat (60) @(posedge vs);
    match(0,45);

    rst_counters;
    raw=0;
    ana=FULL_RIGHT;
    repeat (60) @(posedge vs);
    match(0,60);

    // left
    rst_counters;
    raw=0;
    ana=LEFT_25;
    repeat (60) @(posedge vs);
    match(15,0);

    rst_counters;
    raw=0;
    ana=LEFT_50;
    repeat (60) @(posedge vs);
    match(30,0);

    rst_counters;
    raw=0;
    ana=LEFT_75;
    repeat (60) @(posedge vs);
    match(45,0);

    rst_counters;
    raw=0;
    ana=FULL_LEFT;
    repeat (60) @(posedge vs);
    match(60,0);

    // raw used when analog inputs are null
    repeat(30) begin
        raw[0] = $random; @(posedge clk);
        raw[1] =~raw[0];  @(posedge clk);
        ana=0;
        @(posedge vs) begin
            if(joy!=raw) begin
                $display("Digital directions must prevail.\nFAIL");
                $finish;
            end
        end
    end
    $display("PASS");
    $finish;
end

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    (               ),
    .lhbl       ( vs            ),
    .lvbl       (               ),
    .v          ( v             ),  // for faster simulation
    .framecnt   (               )
);

endmodule

module count_times(
    input   rst, vs, joy,
    output reg [31:0] times=0
);

always @(posedge vs, posedge rst) begin
    if(rst) begin
        times=0;
    end else begin
        times <= times+joy;
    end
end

endmodule