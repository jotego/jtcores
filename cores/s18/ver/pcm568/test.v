`timescale 1ns/1ps

module test;

wire [ 7:0] ram1_din, cpu_din;
reg  [ 7:0] ram0_dout, ram1_dout, cpu_dout;
wire [15:0] ram0_addr, ram1_addr;
wire        ram1_we;
wire [ 9:0] snd_l, snd_r;
reg         cpu_wr;
reg  [12:0] cpu_addr;

reg       rst, clk, cen=0;
reg [7:0] ram[0:65535];

initial begin
    clk = 0;
    forever #2.5 clk = ~clk;
end

integer cnt;

initial begin
    rst=0;
    for(cnt=0;cnt<65536;cnt=cnt+1) ram[cnt]=$random;
    #10 rst=1;
    #30 rst=0;
end

always @(negedge clk) cen <= ~cen;

always @(posedge clk) begin
    if( ram1_we ) ram[ram1_addr] <= ram1_din;
    ram0_dout <= ram[ram0_addr];
    ram1_dout <= ram[ram1_addr];
end

localparam [12:0] CHEN=13'd8, CTRL=13'd7, CHST=13'd6, FDH=13'd3, FDL=13'd2,
                  PAN=13'd1, ENV=13'd0;

initial begin
    cpu_wr   = 0;
    cpu_dout = 0;
    cpu_addr = 0;
    repeat(50) @(posedge clk);
    // select channel 5
    @(posedge clk) {cpu_wr, cpu_dout, cpu_addr } = { 1'b1, 8'h45, CTRL };
    @(posedge clk) cpu_wr = 0;
    @(posedge clk) {cpu_wr, cpu_dout, cpu_addr } = { 1'b1, 8'hff, CHEN };
    @(posedge clk) cpu_wr = 0;
    // start address
    @(posedge clk) {cpu_wr, cpu_dout, cpu_addr } = { 1'b1, 8'h24, FDL  };
    @(posedge clk) cpu_wr = 0;
    @(posedge clk) {cpu_wr, cpu_dout, cpu_addr } = { 1'b1, 8'h05, FDH  };
    @(posedge clk) cpu_wr = 0;
    // FD
    @(posedge clk) {cpu_wr, cpu_dout, cpu_addr } = { 1'b1, 8'h3a, CHST };
    @(posedge clk) cpu_wr = 0;
    repeat(10000) @(posedge clk); // the address counter should be still
    // Pan
    @(posedge clk) {cpu_wr, cpu_dout, cpu_addr } = { 1'b1, 8'hff, PAN };
    @(posedge clk) cpu_wr = 0;
    // Env
    @(posedge clk) {cpu_wr, cpu_dout, cpu_addr } = { 1'b1, 8'hff, ENV };
    @(posedge clk) cpu_wr = 0;
    // start channel 5
    @(posedge clk) {cpu_wr, cpu_dout, cpu_addr } = { 1'b1, 8'hc5, CTRL };
    @(posedge clk) cpu_wr = 0;
    @(posedge clk) {cpu_wr, cpu_dout, cpu_addr } = { 1'b1, ~(8'h1<<5), CHEN };  // enable audio (active low)
    repeat(10000) @(posedge clk); // the address counter should count up
    $finish;
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

jtpcm568 uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen           ),

    // CPU interface
    .wr         ( cpu_wr        ),
    .cs         ( 1'b1          ),
    .addr       ( cpu_addr      ), // A12 selects register (0) or memory (1)
    .din        ( cpu_dout      ),
    .dout       ( cpu_din       ),

    // ADPCM RAM
    .ram0_addr  ( ram0_addr     ),
    .ram0_dout  ( ram0_dout     ),
    .ram1_addr  ( ram1_addr     ),
    .ram1_din   ( ram1_din      ),
    .ram1_dout  ( ram1_dout     ),
    .ram1_we    ( ram1_we       ),

    .snd_l      ( snd_l         ),
    .snd_r      ( snd_r         )
);

endmodule