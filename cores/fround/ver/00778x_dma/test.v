module test;

localparam PW=10;
localparam [PW-1:0] OBJ_DX='hAA,OBJ_DY='h55;
localparam [   7:0] XREF=8'h12, YREF=8'h34;
localparam [   2:0] PARSED_AREA={3'b110};
localparam [  15:0] CODEREF=16'hcafe,ATTRREF=16'h1234;

localparam POS_ENABLE=0,
           POS_ATTR=2,
           POS_CODE=3,
           POS_XHI=4,
           POS_XLO=5,
           POS_YHI=6,
           POS_YLO=7;


wire rst, clk, pxl_cen, lvbl, oram_we, dma_bsy;
wire [13:1] oram_addr;
reg  [15:0] check_val, ref_val;
reg  [15:0] oram[0:8191];
reg  [15:0] refram[0:1023];
wire [15:0] oram_din;
reg  [15:0] oram_dout;
reg         lvbl_l, objbufinit;

wire [31:0] framecnt;

always @(posedge clk) if(pxl_cen) begin
    lvbl_l <= lvbl;
    objbufinit <= !lvbl && lvbl_l;
end

initial begin
    // Object RAM
    // fill it with disabled objects
    for(integer k=0;k<8191;k=k+1) begin
        oram[k]=16'h7fff;
    end
    // create a visible object that will get copied
    oram[POS_ENABLE] = 16'h8000;
    oram[POS_ATTR  ] = ATTRREF;
    oram[POS_CODE  ] = CODEREF;
    oram[POS_XHI   ] = 16'h0101;
    oram[POS_XLO   ] = {XREF,XREF};
    oram[POS_YHI   ] = 16'h0101;
    oram[POS_YLO   ] = {YREF,YREF};
    // Reference RAM
    for(integer k=0;k<1023;k=k+1) begin
        refram[k]=16'h0;
    end
    // first object that should be copied
    refram[0]=CODEREF;
    refram[1]={8'h01,XREF}-OBJ_DX;
    refram[2]={8'h01,YREF}-OBJ_DY;
    refram[3]={6'h20,ATTRREF[9:0]};
end


always @(posedge clk) begin
    if(oram_we) oram[oram_addr] <= oram_din;
    oram_dout <=oram[oram_addr];
end

always @(posedge clk) begin
    if(lvbl && dma_bsy) begin
        $display("FAIL: dma_bsy should not be high during active video time");
        $finish;
    end
end

always @(posedge objbufinit) if(framecnt==2) begin
    for(integer cnt=0;cnt<11'h400;cnt=cnt+1) begin
        check_val = oram[{PARSED_AREA,cnt[9:0]}];
        ref_val   = refram[cnt];
        if(check_val!=ref_val) begin
            $display("FAIL at parsed position $%0X. Got $%X expected $%X",{PARSED_AREA,cnt[9:0]},check_val,ref_val);
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
    .lvbl       ( lvbl          ),
    .framecnt   ( framecnt      )
);

jt00778x_dma #(.PW(PW)) uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .objbufinit ( objbufinit    ),
    .lvbl       ( lvbl          ),

    .dma_on     ( 1'b0          ),
    .dma_bsy    ( dma_bsy       ),
    .obj_dx     ( OBJ_DX        ),
    .obj_dy     ( OBJ_DY        ),

    .oram_addr  ( oram_addr     ),
    .oram_we    ( oram_we       ),
    .oram_dout  ( oram_dout     ),
    .oram_din   ( oram_din      )
);

endmodule