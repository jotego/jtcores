module test;

`include "test_tasks.vh"

wire       clk;
reg        ioctl_addr;
reg  [9:0] din;
wire [7:0] ioctl_din;

jtframe_simdumper #(.DW(10)) uut(
    .clk        ( clk       ),
    .data       ( din       ),
    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din )
);

initial begin
    din=0;
    ioctl_addr=0;
    repeat(10) @(posedge clk);
    assert_msg(ioctl_din===8'd0,"expected 0");
    din=10'h25a;
    repeat(2) @(posedge clk);
    assert_msg(ioctl_din===8'h5a,"expected 8'h5a");
    ioctl_addr=1;
    repeat(2) @(posedge clk);
    assert_msg(ioctl_din[1:0]===2'd2,"expected 2'h02");
    pass();
end

jtframe_test_clocks clocks(
    .clk        ( clk           )
);

endmodule
