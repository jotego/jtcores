module test;

wire rst, clk, pxl_cen, objbufinit, oram_we;
wire [13:1] oram_addr;
reg  [15:0] mem[0:1023];
wire [15:0] oram_din;
reg  [15:0] oram_dout;

wire [31:0] framecnt;


always @(posedge clk) begin
    if(oram_we) mem[oram_addr[10:1]] <= oram_din;
    oram_dout<=mem[oram_addr[10:1]];
end

always @(posedge objbufinit) if(framecnt==2) begin
    for(integer cnt=0;cnt<11'h400;cnt=cnt+1) begin
        if(mem[cnt]!=={6'd0,~cnt[9:0]}) begin
            $display("FAIL at position %0d. Got $%X expected $%X",cnt,mem[cnt],{6'd0,~cnt[9:0]});
            $finish;
        end
    end
    $display("PASS");
    $finish;
end

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .lhbl       (               ),
    .lvbl       ( objbufinit    ),
    .framecnt   ( framecnt      )
);

jt00778x_copy_lut uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .objbufinit ( objbufinit    ),
    .dma_on     ( 1'b1          ),
    .dma_bsy    (               ),

    .oram_addr  ( oram_addr     ),
    .oram_we    ( oram_we       ),
    .oram_dout  ( {6'd0,~oram_addr[10:1]} ),
    .oram_din   ( oram_din      )
);

endmodule