module test;

`include "test_tasks.vh"

localparam TIMEOUT=400_000_000, MAXFRAMES=3, PXLEND=7;

reg         clk, rst, pxl_cen, wrn;
wire        frame_start, line_inc, raster, vb;
reg  [ 2:0] cnt_sel;
reg  [15:0] cpu_dout;
wire [ 8:0] vdump;
integer     framecnt=0;

initial begin
    clk=0;
    forever #(10.416/2) clk=~clk;   // 96 MHz
end

initial begin
    rst=0;
    #30  rst=1;
    #300 rst=0;
    #TIMEOUT
    $display("FAIL: Timeout");
    $finish;
end

integer rasterhits=0;

always @(posedge vb) begin
    framecnt<=framecnt+1;
    if(framecnt==MAXFRAMES) begin
        if(rasterhits==0) begin
            fail();
        end else begin
            pass();
        end
    end
end

integer cnt=0;

always @(posedge clk) begin
    cnt<=cnt==PXLEND ? 0 : cnt+1;
    pxl_cen <= cnt==PXLEND;  // 6MHz or 8MHz
end

always @(posedge raster) begin
    rasterhits <= rasterhits+1;
    assert_msg(vdump==9'h20,"raster must occur at line $20");
end

task write_cnt(input [2:0]sel, input [8:0] data); begin
    wrn = 0;
    cnt_sel = sel;
    cpu_dout = {1'b1, 6'd0, data};
    repeat(2) @(posedge pxl_cen);
    wrn = 1;
    repeat(2) @(posedge pxl_cen );
end endtask

initial begin
    wrn = 1;
    cnt_sel = 0;
    cpu_dout = 0;
    repeat(4) @(posedge line_inc);
    write_cnt(3'b001,9'h023);
    write_cnt(3'b010,9'h106);
    write_cnt(3'b100,9'h000);
end

jtcps2_raster uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .frame_start( frame_start   ),
    .line_inc   ( line_inc      ),

    // interface with CPU
    .cnt_sel    ( cnt_sel       ),
    .wrn        ( wrn           ),
    .cpu_dout   ( cpu_dout      ),
    .cnt_dout   (               ),

    .raster     ( raster        )
);

jtcps1_timing u_timing(
    .clk        ( clk       ),
    .cen8       ( pxl_cen   ),

    .hdump      (           ),
    .vdump      ( vdump     ),
    .vrender    (           ),
    .vrender1   (           ),
    .line_start (           ),
    .line_inc   ( line_inc  ),
    .frame_start(frame_start),
    // to video output
    .HS         (           ),
    .VS         (           ),
    .VB         ( vb        ),
    .preVB      (           ),
    .HB         (           ),
    .debug_bus  ( 8'd0      )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

endmodule // test
