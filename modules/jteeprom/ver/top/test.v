`timescale 1ns/1ps

module test;

parameter CMDCNT=3;
parameter CMDFILE="dinoboot.bin";

reg clk, rst, sclk, di, cs, rcen=0;
integer cnt, start=80;
wire    do;

reg         dump_en = 0;
reg  [ 5:0] dump_addr = 0;
wire [ 7:0] dump_dout;

reg [2:0] cmd[0:CMDCNT-1];

initial begin
    $display("Reading %0d lines from %s",CMDCNT, CMDFILE );
    $readmemb( CMDFILE, cmd );
end

initial begin
    clk  = 0;
    di   = 0;
    cs   = 0;
    sclk = 0;
    cnt  = 0;
    forever #20 clk = ~clk;
end

initial begin
    rst = 0;
    #50 rst = 1;
    #50 rst = 0;
end

always @(posedge clk) begin
    rcen = ~rcen;
    if( start ) start = start-1;
    else if(rcen && !dump_en ) begin
        { cs, sclk, di } <= cmd[cnt];
        cnt <= cnt+1;
        if( cnt == CMDCNT-1 ) begin
            dump_en <= 1;
        end
    end
    if( dump_en && rcen ) begin
        $display("%X: %0X ", dump_addr, dump_dout);
        dump_addr <= dump_addr + 1;
        if( &dump_addr ) $finish;
    end
end

reg [15:0] read_data;

always @(negedge sclk) begin
    if( cs )
        read_data <= { read_data[14:0], do };
    else
        read_data <= 0;
end

jt9346 #(.AW(7),.DW(8),.CW(7)) UUT(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .sclk   ( sclk  ),
    .sdi    ( di    ),
    .sdo    ( do    ),
    .scs    ( cs    ),
    // Dump
    .dump_clk (clk      ),
    .dump_addr(dump_addr),
    .dump_dout(dump_dout)
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end

endmodule