module test;

reg                rst, clk, cen4=0, cs, wrn;
reg         [ 7:0] addr;
reg         [ 7:0] din;
wire        [ 7:0] dout;
wire signed [14:0] snd;

initial begin
    clk=0;
    forever #10 clk=~clk;
end

integer k;

initial begin
    rst  = 0;
    cs   = 0;
    din  = 0;
    addr = 0;
    wrn  = 0;
    #40 rst=1;
    // init memory
    din = 0;
    repeat(256) begin
        @(posedge clk);
        addr = addr + 1'd1;
        cs   = 1;
        wrn  = 0;
    end
    #40 rst=0;
    repeat (100) @(posedge cen4);
    // load a waveform
    din = -128;
    for(k=0;k<32;k=k+1) begin
        @(posedge cen4);
        addr = k;
        din  = din+8;
        cs   = 1;
        wrn  = 0;
    end
    // frequency
    @(posedge cen4);
    addr = 8'h80;
    din  = 8'h10;
    @(posedge cen4);
    addr = 8'h81;
    din  = 0;
    // volume
    @(posedge cen4);
    addr = 8'h8A;
    din  = 8;
    repeat (10) begin
       @(posedge cen4);
       wrn = 1;
    end
    // key on
    @(posedge cen4);
    addr = 8'h8F;
    din  = 1;
    wrn  = 0;

    repeat (100000) begin
       @(posedge cen4);
       wrn = 1;
    end
    $finish;
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

always @(posedge clk) cen4 <= ~cen4;

jt051649 uut(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen4   ( cen4      ),  // set to 4x the frequency on schematics
    .cs     ( cs        ),
    .wrn    ( wrn       ),
    .addr   ( {8'h98, addr } ),
    .din    ( din       ),
    .dout   ( dout      ),
    .snd    ( snd       )    // Do not clamp at this level
    ,.debug_bus( 8'h5   )
);

endmodule