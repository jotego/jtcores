// Sweeps jtframe_hretime through every scale step and checks, for each line:
//   - every source pixel comes out once, in order, byte exact
//   - the active window is resized by scale/STEP
//   - the window stays centred on the same point of the line
// A 512-pixel line with an 80-pixel front porch leaves room to check the
// complete pixel sequence even at the largest stretch setting.

module test;

`include "test_tasks.vh"

// DIV is what jtframe derives from the core's pixel clock: 8 at 48 MHz,
// 12 with JTFRAME_PXLCLK=8 on a 96 MHz core, 16 at 96 MHz
`ifdef HRETIME_CRT480I
localparam DIV=6, ALT_X2=18, MODES=3;
`elsif HRETIME_CRT480I48
localparam DIV=8, ALT_X2=9, MODES=3;
`elsif HRETIME_DIV12
localparam DIV=12;
`elsif HRETIME_DIV16
localparam DIV=16;
`else
localparam DIV=8;
`endif
`ifndef HRETIME_CRT480I
`ifndef HRETIME_CRT480I48
localparam ALT_X2=DIV<<1, MODES=1;
`endif
`endif
localparam DW=24, STEP=64, DEPTH=128, HW=10;
localparam HACTIVE=512, FP=80, HSW=32, BP=80,
           HTOTAL=HACTIVE+FP+HSW+BP;
localparam VACTIVE=3, VTOTAL=4;
localparam MAXDIV=DIV>((ALT_X2+1)>>1) ? DIV : ((ALT_X2+1)>>1);
localparam TOL=3*MAXDIV;   // 3 pixels

reg               clk=0;
reg  [      31:0] tick=0;
reg  [       7:0] divcnt=0;
reg               div_alt=0, pixel_alt=0;
reg  [       9:0] hcnt=0, vcnt=0;
reg               ce_in=0, enable=0, check_en=0;
reg  signed [3:0] scale=0;

wire              hs_in = hcnt>=HACTIVE+FP && hcnt<HACTIVE+FP+HSW,
                  vs_in = vcnt==VACTIVE && hcnt<HSW,
                  de_in = hcnt<HACTIVE && vcnt<VACTIVE;
wire [   DW-1:0]  din   = { 16'd0, hcnt[7:0] };

wire              ce_out, hs_out, vs_out, de_out;
wire [   DW-1:0]  dout;

integer errs=0, sweep=0, sc=0, mode=0;
wire [7:0] pixel_last;
wire [31:0] source_x2;
assign source_x2 = div_alt ? ALT_X2 : DIV<<1;
`ifdef HRETIME_CRT480I
assign pixel_last = div_alt ? (pixel_alt ? 8'd9 : 8'd7) : DIV-1;
`elsif HRETIME_CRT480I48
assign pixel_last = div_alt ? (pixel_alt ? 8'd4 : 8'd3) : DIV-1;
`else
assign pixel_last = DIV-1;
`endif

always #5 clk <= ~clk;

always @(posedge clk) begin
    tick  <= tick+1;
    ce_in <= 0;
    if( divcnt>=pixel_last ) begin
        divcnt <= 0;
        ce_in  <= 1;
        pixel_alt <= ~pixel_alt;
    end else begin
        divcnt <= divcnt+1'b1;
    end
end

always @(posedge clk) if( ce_in ) begin
    hcnt <= hcnt==HTOTAL-1 ? 10'd0 : hcnt+1'd1;
    if( hcnt==HTOTAL-1 ) vcnt <= vcnt==VTOTAL-1 ? 10'd0 : vcnt+1'd1;
end

jtframe_hretime #(.DIV(DIV),.DIV_ALT_X2(ALT_X2),.DEPTH(DEPTH)) uut(
    .clk    ( clk       ),
    .ce_in  ( ce_in     ),
    .enable ( enable    ),
    .div_alt( div_alt   ),
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
        if( check_en && vcnt<VACTIVE && got>0 ) begin
            span     = t_last-t_first;
            ctr      = tick-((t_first+t_last)/2);
            exp_span = ((HACTIVE-1)*source_x2*(STEP+sc))/(STEP<<1);
            exp_ctr  = ((2*(HACTIVE+FP)-(HACTIVE-1))*source_x2)/4;
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
        t_first <= 0;
        t_last  <= 0;
    end
end

// the FIFO must never wrap onto unread data
always @(posedge clk) if( uut.push && ((uut.wptr+1'd1)==uut.rptr) ) begin
    $display("scale %0d: FIFO overflow, DEPTH=%0d is too small",sc,DEPTH);
    errs = errs+1;
end

// reader must never consume more pixels than writer produced
always @(posedge clk) if( uut.ce_slow && uut.started && uut.rcnt>uut.wcnt ) begin
    $display("scale %0d: FIFO underrun rcnt=%0d wcnt=%0d",sc,uut.rcnt,uut.wcnt);
    errs = errs+1;
end

task wait_line; begin
    @(posedge hs_out);
end endtask

initial begin
  for( mode=0; mode<MODES; mode=mode+1 ) begin
    check_en = 0;
    div_alt = mode==1;
    enable = 0;
    scale  = 0;
    sc     = 0;
    repeat(3) wait_line;
    // bypass (enable off) must be transparent
    check_en = 1;
    repeat(3) wait_line;
    check_en = 0;
    enable   = 1;
    repeat(5) wait_line;
    // sweep -8..+8 effective: input -8..+7 maps to effective -8..-1,+1..+8
    for( sweep=-8; sweep<8; sweep=sweep+1 ) begin
        check_en = 0;
        sc       = sweep < 0 ? sweep : sweep+1;  // effective scale for checks
        scale    = sweep[3:0];
        repeat(5) wait_line;    // scale_l latches at hsync + pipeline settle
        check_en = 1;
        repeat(4) wait_line;
    end
    // ---- mid-line enable toggle: latched at hsync, current line unaffected ----
    check_en = 0;
    sc    = 5;       // input 4 → effective +5
    scale = 4;
    repeat(6) wait_line;
    check_en = 1;
    repeat(2) wait_line;
    // toggle enable off mid-active then back on
    @(posedge clk) while( hcnt!=HACTIVE/2 ) @(posedge clk);
    enable = 0;
    repeat(DIV*4) @(posedge clk);
    enable = 1;
    // enable_l doesn't change until next hsync, so remaining lines are fine
    repeat(3) wait_line;
    check_en = 0;

    // ---- mid-line scale change: latched at hsync, current line keeps old scale ----
    sc    = 4;       // input 3 → effective +4
    scale = 3;
    repeat(6) wait_line;
    check_en = 1;
    repeat(2) wait_line;
    @(posedge clk) while( hcnt!=HACTIVE/2 ) @(posedge clk);
    scale = -3;
    // scale_l stays 3 until next hsync, so this line completes at old scale
    repeat(1) wait_line;
    check_en = 0;
    // now let scale_l=-3 settle and verify
    sc    = -3;      // input -3 → effective -3
    repeat(6) wait_line;
    check_en = 1;
    repeat(3) wait_line;
    check_en = 0;

    // ---- disable: bypass must be transparent ----
    enable   = 0;
    scale    = 0;
    sc       = 0;
    repeat(6) wait_line;
    check_en = 1;
    repeat(3) wait_line;

    check_en = 0;
    $display("DIV=%0d ALT_X2=%0d alternate=%b: scale sweep complete",DIV,ALT_X2,div_alt);
  end
    if( errs==0 ) pass(); else fail();
end

initial begin
    #160_000_000;
    $display("timeout");
    fail();
end

endmodule
