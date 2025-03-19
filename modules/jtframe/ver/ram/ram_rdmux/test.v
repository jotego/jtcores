`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

wire       rst, clk;
wire [7:0] a_data, b_data, rd_data;
reg  [7:0] wr_data;
reg  [9:0] wr_addr, a_addr, b_addr;
wire [9:0] rd_addr;
reg        wr;

initial begin
    @(negedge rst);
    wr=0;
    a_addr = 0;
    b_addr = 0;
    repeat (10) @(posedge clk);
    wr_data=0;
    wr_addr=0;
    wr=1;
    repeat(2) @(posedge clk);
    wr_data=#1 8'haa;
    wr_addr=#1 1;
    wr=1;
    @(posedge clk);
    wr_data=#1 8'hbb;
    wr_addr=#1 2;
    wr=1;
    repeat(2) @(posedge clk);
    wr=0;
    repeat (20) @(posedge clk);
    a_addr = #1 1;
    repeat (3) @(posedge clk);
    assert_msg(a_data==8'haa,"A output must be AA");
    b_addr = #1 2;
    repeat (3) @(posedge clk);
    assert_msg(b_data==8'hbb,"B output must be BB");
    repeat (20) @(posedge clk);
    pass();
end

jtframe_dual_ram u_ram(
    // Port 0
    .clk0   ( clk       ),
    .data0  ( wr_data   ),
    .addr0  ( wr_addr   ),
    .we0    ( wr        ),
    .q0     (           ),
    // Port 1
    .clk1   ( clk       ),
    .data1  ( 8'd0      ),
    .addr1  ( rd_addr   ),
    .we1    ( 1'b0      ),
    .q1     ( rd_data   )
);

jtframe_ram_rdmux uut(
    .clk    ( clk       ),

    // to RAM
    .addr   ( rd_addr   ),
    .data   ( rd_data   ),

    // read ports
    .addr_a ( a_addr    ),
    .addr_b ( b_addr    ),
    .douta  ( a_data    ),
    .doutb  ( b_data    )
);

jtframe_test_clocks clocks(
    .rst    ( rst       ),
    .clk    ( clk       )
);

endmodule