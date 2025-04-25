module test;

wire        rst, clk, lvbl, lhbl, busy, copy;
wire [ 1:0] ram_we;
wire [12:1] ram_addr;
wire [ 8:0] vdump;
wire [15:0] ram_din;
reg  [15:0] last, ram_dout;

`include "test_tasks.vh"

assign copy     = vdump==9'h50;

initial begin
    repeat (3) @(negedge lvbl);
    pass();
end

always @(posedge clk) begin
    if(ram_we==0) begin
        ram_dout <= {4'd0,ram_addr};
        last <= ram_dout;
    end else if(busy) begin
        assert_msg(last==ram_din,"written data must match read data");
        assert_msg((ram_addr-3'd3)==ram_din[11:0],"data must be copied 3 words after where it was read from");
    end
    assert_msg(ram_we==0 || !lvbl,"RAM writes must occur during lvbl");
end

jtthundr_objdma u_objdma(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .copy       ( copy      ),
    .lvbl       ( lvbl      ),

    .busy       ( busy      ),
    .ram_we     ( ram_we    ),
    .ram_addr   ( ram_addr  ),
    .ram_dout   ( ram_dout  ),
    .ram_din    ( ram_din   )
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .lvbl       ( lvbl          ),
    .lhbl       ( lhbl          ),
    .v          ( vdump         )
);

endmodule