`timescale 1ns / 1ps

module test;

reg         rst_n;
reg         clk;
reg         cen = 1'b0;
wire        adc_convst;
wire        adc_sck;
wire        adc_sdi;
wire [11:0] adc_read;

initial begin
    clk = 1'b0;
    #20;
    forever clk = #8 ~clk;
end

initial begin
    rst_n = 1;
    #4;
    rst_n = 0;
    #10;
    rst_n = 1;
    #100_000;
    $finish;
end

always @(negedge clk) cen <= ~cen;

reg [11:0] adc_val;
reg [ 1:0] cnt2 = 2'd0;
reg [11:0] mem[0:3];

initial begin
    mem[0] <= 12'h023;
    mem[1] <= 12'h11f;
    mem[2] <= 12'h1e5;
    mem[3] <= 12'hfbe;
end

always @(posedge adc_convst) begin
    cnt2 <= cnt2==2'd3 ? 2'd0 : cnt2+2'd1;
    adc_val <= mem[cnt2];
end

wire adc_sdo = adc_val[11];

always @(posedge adc_sck) begin
    adc_val <= {adc_val[10:0], 1'b0};
end

jtframe_2308 uut(
    .rst_n      ( rst_n      ),
    .clk        ( clk        ),
    .cen        ( cen        ),
    .adc_sdi    ( adc_sdi    ),
    .adc_convst ( adc_convst ),
    .adc_sck    ( adc_sck    ),
    .adc_sdo    ( adc_sdo    ),
    .adc_read   ( adc_read   )
);

`ifdef NCVERILOG
initial begin
    $shm_open("test.shm");
    $shm_probe(test,"AS");
end
`else 
initial begin
    $dumpfile("test.fst");
    $dumpvars;
end
`endif

endmodule // test