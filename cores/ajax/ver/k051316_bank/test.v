`timescale 1ns / 1ps

module test;
reg        clk=0, rst=1, cs=0, rnw=1;
reg  [3:0] addr=0;
reg  [7:0] din=0;
wire [12:0] ckbank;

always #5 clk=~clk;

jtk051316_mmr uut(
    .rst        ( rst    ),
    .clk        ( clk    ),
    .cs         ( cs     ),
    .addr       ( addr   ),
    .rnw        ( rnw    ),
    .din        ( din    ),
    .ckbank     ( ckbank ),
    .ioctl_addr ( 4'd0   ),
    .debug_bus  ( 8'd0   )
);

task write_reg(input [3:0] reg_addr, input [7:0] value);
begin
    @(negedge clk);
    addr=reg_addr;
    din=value;
    cs=1;
    rnw=0;
    @(negedge clk);
    cs=0;
    rnw=1;
end
endtask

task check_bank(input [12:0] expected);
begin
    #1;
    if (ckbank !== expected) begin
        $display("FAIL: bank=%04h expected=%04h",ckbank,expected);
        $finish;
    end
end
endtask

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    repeat(2) @(negedge clk);
    rst=0;
    write_reg(4'hc,8'h01);
    write_reg(4'hd,8'h00);
    check_bank(13'h001);
    write_reg(4'hc,8'hfe);
    write_reg(4'hd,8'h13);
    check_bank(13'h13fe);
    write_reg(4'hd,8'hff);
    check_bank(13'h1ffe);
    $display("PASS");
    $finish;
end
endmodule
