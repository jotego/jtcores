`timescale 1ns / 1ps

module test;

reg clk, rst, pxl_cen=1'b0;

initial begin
    clk = 1'b0;
    forever #20 clk = ~clk;
end

initial begin
    rst = 1'b0;
    #300 rst=1'b1;
    #300 rst = 1'b0;
end

integer hcnt=0, vcnt=0, framecnt=0;
reg hb=0,vb=0;
wire hb_out, vb_out;

integer cen_cnt=0;

always @(posedge clk) begin
    cen_cnt <= cen_cnt==5 ? 0 : cen_cnt + 1;
    pxl_cen <= cen_cnt==0;
end

always @(posedge clk) if(pxl_cen) begin
    hcnt <= hcnt==383 ? 0 : hcnt + 1;
    if( hcnt == 256+32 )  begin
        hb=1'b1;
        vcnt <= vcnt+1;
        if( vcnt == 224 ) begin
            vb <= 1'b1;
            framecnt <= framecnt + 1;
        end
        if( vcnt == 256 ) begin
            vb <= 1'b0;
            vcnt <= 0;
        end
    end
    if( hcnt == 32 )  hb=1'b0;
    if( framecnt == 3 ) $finish;
end

wire [11:0] game_rgb = { 12'habc };
wire [ 3:0] red, green, blue;
wire        pause = 1'b1;

`define AVATARS

jtframe_credits #(.PAGES(3), .SPEED(2)) uut(
    .clk         ( clk              ),
    .rst         ( rst              ),
    .pxl_cen     ( pxl_cen          ),
    // input image
    .HB          ( hb               ),
    .VB          ( vb               ),
    .rgb_in      ( game_rgb         ),
    .enable      ( pause            ),
    // output image
    .HB_out      ( hb_out           ),
    .VB_out      ( vb_out           ),
    .rgb_out     ({red, green, blue})
);

initial begin
    $dumpfile("test.lxt");  
    $dumpvars;  
end

endmodule