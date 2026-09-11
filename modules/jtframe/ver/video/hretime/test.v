// Sweeps jtframe_hretime through every scale step and checks, for each line:
//   - every source pixel comes out once, in order, byte exact
//   - the active window is resized by scale/STEP
//   - the window stays centred on the same point of the line
// A 256/384 line is used because that is the usual jtcores blanking budget:
// at the extreme step the active region grows by 32 pixels, which still fits
// inside the 48-pixel front porch.

module test;

`include "test_tasks.vh"

// DIV is what jtframe derives from the core's pixel clock: 8 at 48 MHz,
// 12 with JTFRAME_PXLCLK=8 on a 96 MHz core, 16 at 96 MHz
`ifdef HRETIME_DIV12
localparam DIV=12;
`elsif HRETIME_DIV16
localparam DIV=16;
`else
localparam DIV=8;
`endif
localparam DW=24, STEP=64, DEPTH=64, HW=10;
localparam HACTIVE=256, FP=48, HSW=32, BP=48,
           HTOTAL=HACTIVE+FP+HSW+BP;
localparam VACTIVE=3, VTOTAL=4;
localparam TOL=3*DIV;   // 3 pixels

reg               clk=0;
reg  [      31:0] tick=0;
reg  [  DIV-1:0]  divcnt=1;
reg  [       9:0] hcnt=0, vcnt=0;
reg               ce_in=0, enable=0, check_en=0;
reg  signed [3:0] scale=0;

wire              hs_in = hcnt>=HACTIVE+FP && hcnt<HACTIVE+FP+HSW,
                  vs_in = vcnt==VACTIVE && hcnt<HSW,
                  de_in = hcnt<HACTIVE && vcnt<VACTIVE;
wire [   DW-1:0]  din   = { 16'd0, hcnt[7:0] };

wire              ce_out, hs_out, vs_out, de_out;
wire [   DW-1:0]  dout;

integer errs=0, sweep=0, sc=0;

always #5 clk <= ~clk;

always @(posedge clk) begin
    tick  <= tick+1;
    ce_in <= 0;
    if( divcnt[DIV-1] ) begin
        divcnt <= 1;
        ce_in  <= 1;
    end else begin
        divcnt <= divcnt<<1;
    end
end

always @(posedge clk) if( ce_in ) begin
    hcnt <= hcnt==HTOTAL-1 ? 10'd0 : hcnt+1'd1;
    if( hcnt==HTOTAL-1 ) vcnt <= vcnt==VTOTAL-1 ? 10'd0 : vcnt+1'd1;
end

jtframe_hretime #(.DW(DW),.DIV(DIV),.STEP(STEP),.DEPTH(DEPTH),.HW(HW)) uut(
    .clk    ( clk       ),
    .ce_in  ( ce_in     ),
    .enable ( enable    ),
    .scale  ( scale     ),

    .din    ( din       ),
    .hs_in  ( hs_in     ),
    .vs_in  ( vs_in     ),
    .de_in  ( de_in     ),

    .ce_out ( ce_out    ),
    .dout   ( dout      ),
    .hs_out ( hs_out    ),
    .vs_out ( vs_out    ),
    .de_out ( de_out    )
);

// ---- line collection -------------------------------------------------------
reg           ce_d=0, hs_out_l=0;
integer       got=0;
reg  [  31:0] t_first=0, t_last=0;
integer       exp_span, exp_ctr, span, ctr;

always @(posedge clk) begin
    ce_d     <= ce_out;
    hs_out_l <= hs_out;
end

always @(posedge clk) begin
    if( ce_d && de_out ) begin
        if( got==0 ) t_first <= tick;
        t_last <= tick;
        if( check_en && dout[7:0]!==got[7:0] ) begin
            $display("line %0d scale %0d: pixel %0d is %02X, expected %02X",
                      vcnt, sc, got, dout[7:0], got[7:0]);
            errs = errs+1;
        end
        got <= got+1;
    end
    if( hs_out & ~hs_out_l ) begin
        if( check_en && vcnt<VACTIVE ) begin
            span     = t_last-t_first;
            ctr      = tick-((t_first+t_last)/2);
            exp_span = ((HACTIVE-1)*DIV*(STEP+sc))/STEP;
            exp_ctr  = ((2*(HACTIVE+FP)-(HACTIVE-1))*DIV)/2;
            if( got!=HACTIVE ) begin
                $display("scale %0d: %0d pixels out, expected %0d",sc,got,HACTIVE);
                errs = errs+1;
            end
            if( span<exp_span-TOL || span>exp_span+TOL ) begin
                $display("scale %0d: active span %0d clk, expected %0d",sc,span,exp_span);
                errs = errs+1;
            end
            if( ctr<exp_ctr-TOL || ctr>exp_ctr+TOL ) begin
                $display("scale %0d: centre at %0d clk before hs, expected %0d",sc,ctr,exp_ctr);
                errs = errs+1;
            end
        end
        got <= 0;
    end
end

// the FIFO must never wrap onto unread data
always @(posedge clk) if( uut.push && ((uut.wptr+1'd1)==uut.rptr) ) begin
    $display("scale %0d: FIFO overflow, DEPTH=%0d is too small",sc,DEPTH);
    errs = errs+1;
end

task wait_line; begin
    @(posedge hs_out);
end endtask

initial begin
    enable = 0;
    scale  = 0;
    repeat(3) wait_line;
    // bypass must be transparent
    enable   = 1;
    check_en = 1;
    repeat(3) wait_line;
    for( sweep=-8; sweep<8; sweep=sweep+1 ) begin
        check_en = 0;
        sc       = sweep;
        scale    = sweep[3:0];
        repeat(3) wait_line;    // nactive needs one line to settle
        check_en = 1;
        repeat(4) wait_line;
    end
    check_en = 0;
    if( errs==0 ) pass(); else fail();
end

initial begin
    #20_000_000;
    $display("timeout");
    fail();
end

endmodule
