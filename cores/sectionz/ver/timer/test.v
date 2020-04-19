`timescale 1ns / 1ps

module test;

reg clk;

initial begin
    clk = 0;
    forever #83.334 clk = ~clk;
end

wire [8:0] V,H;
wire       Hinit, Vinit, LHBL, LHBL_obj, LVBL, LVBL_obj, HS, VS;

jtgng_timer #(.LAYOUT(5)) UUT(
    .clk       ( clk      ),
    .cen6      ( 1'b1     ),   //  6 MHz
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( Hinit    ),
    .Vinit     ( Vinit    ),
    .LHBL      ( LHBL     ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL      ( LVBL     ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       )
);

reg LVBL_Last, LHBL_last, VS_last, HS_last;

wire new_line  = LHBL_last && !LHBL;
wire new_frame = LVBL_Last && !LVBL;
wire new_HS = HS && !HS_last;
wire new_VS = VS && !VS_last;

integer vbcnt=0, vcnt=0, hcnt=0, hbcnt=0, vs0, vs1, hs0, hs1;
integer framecnt=0;

always @(posedge clk) begin
    LHBL_last <= LHBL;
    HS_last   <= HS;
    VS_last   <= VS;
    if( new_HS ) hs1 <= hbcnt;
    if( new_VS ) vs1 <= vbcnt;
    if( new_line ) begin
        LVBL_Last <= LVBL;
        if( new_frame ) begin
            if( framecnt>0 ) begin
                $display("VB count = %3d (sync at %2d)", vbcnt, vs1 );
                $display("V  total = %3d (%.2f Hz)", vcnt, 6e6/(hcnt*vcnt) );
                $display("HB count = %3d (sync at %2d)", hbcnt, hs1 );
                $display("H  total = %3d", hcnt );
                $display("-------------" );
            end
            vbcnt <= 1;
            vcnt  <= 1;
            framecnt <= framecnt+1;
            if( framecnt==1 ) $finish;
        end else begin
            vcnt <= vcnt+1;
            if( !LVBL ) vbcnt <= vbcnt+1;
        end
        hbcnt <= 1;
        hcnt  <= 1;
    end else begin
        hcnt <= hcnt+1;
        if( !LHBL ) hbcnt <= hbcnt+1;
    end
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    $dumpon;
end

endmodule