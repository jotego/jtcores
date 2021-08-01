`timescale 1ns/1ps

module test;

reg         clk, downloading=1'b1;
reg  [21:0] ioctl_addr=22'd0;
reg  [ 7:0] ioctl_dout= 8'd0;
reg         ioctl_wr;

wire [21:0] prog_addr;
wire [ 7:0] prog_data;
wire [ 1:0] prog_mask;
wire        prog_we;
wire [`PROM_W-1:0] prom_we;

jtbiocom_prom_we
    u_uut(
    .clk         (  clk          ),
    .downloading (  downloading  ),
    .ioctl_addr  (  ioctl_addr   ),
    .ioctl_dout  (  ioctl_dout   ),
    .ioctl_wr    (  ioctl_wr     ),
    .prog_addr   (  prog_addr    ),
    .prog_data   (  prog_data    ),
    .prog_mask   (  prog_mask    ),
    .prog_we     (  prog_we      ),
    .prom_we     (  prom_we      )
);

initial begin
    clk = 1'b0;    
    forever #10 clk = ~clk;
end

reg [1:0] cnt=2'b0;

always @(posedge clk) begin
    cnt      <= cnt+2'd1;
    ioctl_wr <= 1'b0;
    if( ioctl_addr < `ROM_LEN && cnt==2'b11 ) begin
        ioctl_addr <= ioctl_addr + 22'd1;
        ioctl_dout <= ioctl_dout+8'd1;
        ioctl_wr   <= 1'b1;
    end else if( ioctl_addr >= `ROM_LEN ) begin
        downloading <= 1'b0;        
        #100 $finish;
    end
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    $dumpon;    
end

endmodule