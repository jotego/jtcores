`timescale 1ns / 1ps

module test;

parameter WIN=4, WOUT=5;

reg             clk;
wire [WOUT-1:0] dout;
wire [ WIN-1:0] din;
reg  [ WIN-1:0] buffer[0:255];
integer         cen_cnt=0;
wire            spl_in, spl_out;
reg  [     7:0] k=8'd0;

assign spl_in = cen_cnt==5;
assign din    = buffer[k];

initial begin
    $readmemh( "buffer.hex", buffer );
    clk = 0;
    forever #10 clk = ~clk;
end

always @(posedge clk) begin
    cen_cnt <= cen_cnt==5 ? 0 : cen_cnt+1;
    if( spl_in ) begin
        k <= k + 1;
        if( &k ) $finish;
    end
end

jtframe_wirebw_unit #(.WIN(WIN),.WOUT(WOUT)) uut(
    .clk    ( clk       ),
    .spl_in ( spl_in    ),
    .enable ( 1'b1      ),
    .din    ( din       ),
    .dout   ( dout      ),
    .spl_out( spl_out   )
);

wire [WIN-1:0] din_dly;

jtframe_sh #(.W(WIN), .L(6)) u_sh(
    .clk    ( clk              ),
    .clk_en ( 1'b1             ),
    .din    ( din              ),
    .drop   ( din_dly          )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    #1000_000 $finish;
end

endmodule