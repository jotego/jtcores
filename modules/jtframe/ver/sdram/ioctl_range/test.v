module test;

`include "test_tasks.vh"

wire clk;
reg  [21:0] addr;
reg  en;
reg  [7:0] din;

wire [ 8:0] addr_rel;
wire inrange;
wire [7:0] dout;

localparam [21:0] START=22'h1220,END=22'h1420;

wire must_be_in  = addr>=START && addr< END;
wire [8:0]arel=addr-START;

initial begin
    en = 0;
    for(addr=0;addr<22'h4000;addr=addr+22'd1) begin
        @(posedge clk);
        assert_msg(inrange==0,"inrange must be gated by en");
        @(posedge clk);
    end
    en = 1;
    for(addr=0;addr<22'h4000;addr=addr+22'd1) begin
        @(posedge clk);
        @(posedge clk);
        assert_msg(inrange==must_be_in, "inrange is wrong");
        assert_msg(addr_rel==arel || !inrange, "addr_rel is wrong");
    end
    pass();
end

jtframe_ioctl_range #(.OFFSET(START),.AW(9)) uut (
    .clk     ( clk      ),
    .addr    ( addr     ),
    .addr_rel( addr_rel ),
    .en      ( en       ),
    .inrange ( inrange  ),
    .din     ( din      ),
    .dout    ( dout     )
);

jtframe_test_clocks clocks(
    .clk        ( clk           )
);

endmodule