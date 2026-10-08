module test;

wire          rst, clk, pxl_cen, lhbl;
wire   [31:0] framecnt;
wire   [ 2:0] step, haddr;
reg    [ 2:0] hsize;
wire   [ 6:0] addr;
wire   [ 3:0] objcnt;
reg    [ 8:0] vrender=0;
reg    [ 4:0] dr_cnt=0;
reg           cen=0;
wire          fail, dr_draw, draw_step;
reg           dr_busy=0, inzone, skip;

always @(posedge clk) cen <= ~cen;

always @(posedge clk) begin
    if(framecnt>3) begin
        $display("PASS");
        $finish;
    end
end

always @(posedge clk) begin
    if( dr_draw && !dr_busy ) begin
        dr_busy <= 1;
        dr_cnt  <= 0;
    end
    if( dr_busy && pxl_cen ) {dr_busy,dr_cnt}<={1'b1,dr_cnt}+1'd1;
end

integer i;

assign draw_step = step==4;
assign objcnt    = addr[6-:4];

initial begin
    skip      = 0;
    inzone    = 0;
    hsize     = 0;
    @(negedge  lhbl);
    wait (step==4);
    wait (step!=4);
    if(step!=0) begin $display("FAIL: should be back at step 0"); $finish; end
    // do a match
    wait (step==2);
    inzone=1;
    wait (step==4);
    wait( objcnt==2 );
    if(!dr_draw) begin $display("FAIL: should be drawing"); $finish; end
    // remove the match
    inzone=0;
    wait (step==2);
    if(dr_draw) begin $display("FAIL: should not be requesting to draw"); $finish; end
    // try a size 4 object
    wait (step==0);
    hsize = 3;
    inzone= 1;
    wait(step==4);
    for(i=0;i<4;i=i+1) begin
        @(posedge dr_draw);
        @(posedge dr_busy);
        if(haddr!=i[2:0]) begin $display("FAIL: should start with count %0d (found %0d)",i,haddr); $finish; end
    end
    hsize=0;
    inzone=0;
    wait( objcnt==6 )
    if(haddr!=3) begin $display("FAIL: the last haddr value must be kept"); $finish; end
    @(negedge  lhbl);
    $display("PASS");
    $finish;
end

jtframe_test_clocks #(.MAXFRAMES(2)) clocks(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .lhbl       ( lhbl      ),
    .lvbl       (           ),
    .framecnt   ( framecnt  )
);

jtframe_objscan #(.OBJW(4),.STW(3))uut(
    .clk        ( clk       ),
    .hs         ( ~lhbl     ),
    .blankn     ( 1'b1      ),
    .vrender    ( vrender   ),
    .vlatch     (           ),

    .draw_step  ( draw_step ),
    .skip       ( skip      ),
    .inzone     ( inzone    ),

    .hsize      ( hsize     ),
    .haddr      ( haddr     ),
    .hsub       (           ),
    .hflip      (           ),

    .dr_busy    ( dr_busy   ),
    .dr_draw    ( dr_draw   ),

    .addr       ( addr      ),
    .step       ( step      )
);

endmodule