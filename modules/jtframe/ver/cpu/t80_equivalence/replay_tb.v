`timescale 1ns/1ps
module replay_tb;
reg clk = 1'b1;
reg reset_n = 1'b0;
reg cen = 1'b1;
reg wait_n = 1'b1;
reg int_n = 1'b1;
reg nmi_n = 1'b1;
reg busrq_n = 1'b1;
reg out0 = 1'b0;
reg [7:0] di = 8'h00;
wire m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n;
wire [15:0] addr;
wire [7:0] dout;
reg [15:0] vectors [0:2000000];
integer out_fd, i, row_count;
reg [31:0] packed_value;

T80s uut (
    .RESET_n(reset_n), .CLK(clk), .CEN(cen), .WAIT_n(wait_n),
    .INT_n(int_n), .NMI_n(nmi_n), .BUSRQ_n(busrq_n), .OUT0(out0),
    .DI(di), .M1_n(m1_n), .MREQ_n(mreq_n), .IORQ_n(iorq_n),
    .RD_n(rd_n), .WR_n(wr_n), .RFSH_n(rfsh_n), .HALT_n(halt_n),
    .BUSAK_n(busak_n), .A(addr), .DOUT(dout)
);

task emit;
    input integer rownum;
    input [31:0] value;
    input [8*4-1:0] phase;
    begin
        $fwrite(out_fd, "%0d,%0s,%032b\n", rownum, phase, value);
    end
endtask

initial begin
    $readmemb("vectors.bin", vectors);
    if(!$value$plusargs("ROWS=%d", row_count)) $fatal(1, "missing ROWS plusarg");
    out_fd = $fopen("outputs.csv", "w");
    if(out_fd == 0) $fatal(1, "cannot open outputs.csv");
    #4 clk = 1'b0;
    for(i=0; i<row_count; i=i+1) begin
        {reset_n,cen,wait_n,int_n,nmi_n,busrq_n,out0} = vectors[i][7:1];
        di = vectors[i][15:8];
        #1;
        packed_value = {m1_n,mreq_n,iorq_n,rd_n,wr_n,rfsh_n,halt_n,busak_n,addr,dout};
        emit(i, packed_value, "fall");
        #4 clk = 1'b1;
        #1;
        packed_value = {m1_n,mreq_n,iorq_n,rd_n,wr_n,rfsh_n,halt_n,busak_n,addr,dout};
        emit(i, packed_value, "rise");
        #4 clk = 1'b0;
    end
    $fclose(out_fd);
    $finish;
end
endmodule
