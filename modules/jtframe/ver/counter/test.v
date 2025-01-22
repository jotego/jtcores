module test;

localparam [8:0] EXPECTED_H=280,EXPECTED_V=240;

wire clk, cen_h, cen_v, lhbl, lvbl, rst;
wire [31:0] framecnt;
wire [ 8:0] cnth,cntv;
reg         lhbl_l;

always @(posedge clk) lhbl_l <= lhbl;
assign cen_v = !lhbl & lhbl_l;

jtframe_counter #(.W(9)) uut_h(~lhbl,clk,cen_h,cnth);
jtframe_counter #(.W(9)) uut_v(~lvbl,clk,cen_v,cntv);


always @(negedge lvbl) begin
    if(cntv!==EXPECTED_V && framecnt>0) begin
        $display("Wrong V count: got %0d, expected %0d",cntv,EXPECTED_V);
        $display("FAIL");
        $finish;
    end
end

always @(negedge lhbl) begin
    if(cnth!==EXPECTED_H && framecnt>0) begin
        $display("Wrong H count: got %0d, expected %0d",cnth,EXPECTED_H);
        $display("FAIL");
        $finish;
    end
    if(framecnt==2) begin
        $display("PASS");
        $finish;
    end
end

jtframe_test_clocks clocks(
    .rst        (               ),
    .clk        ( clk           ),
    .pxl_cen    ( cen_h         ),
    .lhbl       ( lhbl          ),
    .lvbl       ( lvbl          ),
    .framecnt   ( framecnt      )
);

endmodule 