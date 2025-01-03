module test;

localparam AW=10,DW=AW;

wire [AW-1:0] dma_addr;
reg  [AW-1:0] rd_addr=0;
wire [DW-1:0] dma_data, rd_data;
wire          rst, clk, pxl_cen, lvbl;
wire   [31:0] framecnt;
reg  [AW-1:0] rd_addrl;
reg           cen=0;
wire          fail;

assign dma_data=dma_addr;
assign fail    = rd_data!=rd_addr && cen;

always @(posedge clk) cen <= ~cen;

always @(posedge clk) begin
    if(framecnt>3) begin
        $display("PASS");
        $finish;
    end
end

always @(posedge clk) if(framecnt>2 && cen) begin
    rd_addr <= rd_addr+1'b1;
    if(fail) begin
        $display("Unexpected data %X (expecting %X)",rd_data,rd_addr);
        $display("FAIL");
        $finish;
    end
end

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .lhbl       (               ),
    .lvbl       ( lvbl          ),
    .framecnt   ( framecnt      )
);

jtframe_framebuf #(.AW(AW),.DW(DW)) uut(
    .clk        ( clk           ),
    .lvbl       ( lvbl          ),
    .dma_addr   ( dma_addr      ),
    .dma_data   ( dma_data      ),

    .rd_addr    ( rd_addr       ),
    .rd_data    ( rd_data       )
);

endmodule