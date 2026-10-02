// jt352 testbench: plays the golden.py register script against a synthetic
// ROM and compares snd_l/snd_r sample by sample with the MAME-ported model
`timescale 1ns/1ps

module test;

reg         clk=0, rst=1, cen=0;
reg         cs=0, rnw=1;
reg  [15:1] addr=0;
reg  [ 1:0] dsn=2'b11;
reg  [15:0] din=0;
wire [15:0] dout;
wire [23:0] rom_addr;
wire [ 7:0] rom_data;
wire        rom_cs, rom_ok, sample;
wire signed [15:0] snd_l, snd_r;
wire [ 7:0] st_dout;

jt352 uut(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .cs         ( cs        ),
    .addr       ( addr      ),
    .rnw        ( rnw       ),
    .dsn        ( dsn       ),
    .din        ( din       ),
    .dout       ( dout      ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( rom_data  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .snd_l      ( snd_l     ),
    .snd_r      ( snd_r     ),
    .sample     ( sample    ),
    .debug_bus  ( 8'd0      ),
    .st_dout    ( st_dout   )
);

always #10 clk = ~clk;
always @(posedge clk) cen <= ~cen;   // 288 cen = 576 clk per sample

// ROM model with a few cycles of latency, ok drops on address change
reg [ 7:0] rom[0:4095];
reg [23:0] la=0;
reg [ 1:0] okc=0;
always @(posedge clk) begin
    la <= rom_addr;
    if( !rom_cs || rom_addr!=la ) okc <= 0;
    else if( okc!=2'd3 ) okc <= okc+2'd1;
end
assign rom_ok   = rom_cs && okc>=2'd2 && rom_addr==la;
assign rom_data = rom[rom_addr[11:0]];

reg [31:0] wr [0:63];
reg [15:0] expd[0:2047];
integer i, n, errs=0, sidx=0;

initial begin
    for( i=0; i<64; i=i+1 ) wr[i] = 32'hffffffff;
    $readmemh("rom.hex",      rom );
    $readmemh("writes.hex",   wr  );
    $readmemh("expected.hex", expd);
    if( !$value$plusargs("n=%d", n) ) n = 400;
    rst = 1;
    repeat(8) @(posedge clk);
    rst = 0;
    repeat(4) @(posedge clk);
    i = 0;
    while( wr[i]!==32'hffffffff && i<64 ) begin
        @(negedge clk);
        cs   = 1;
        rnw  = 0;
        dsn  = 2'b00;
        addr = wr[i][30:16];
        din  = wr[i][15:0];
        @(negedge clk);
        cs   = 0;
        rnw  = 1;
        dsn  = 2'b11;
        @(negedge clk);
        i = i+1;
    end
end

always @(posedge clk) if( sample ) begin
    if( sidx<n ) begin
        if( snd_l !== $signed(expd[sidx*2]) || snd_r !== $signed(expd[sidx*2+1]) ) begin
            errs = errs+1;
            if( errs<=10 )
                $display("MISMATCH @%0d: L got %04x exp %04x | R got %04x exp %04x",
                    sidx, snd_l, expd[sidx*2], snd_r, expd[sidx*2+1]);
        end
    end
    sidx = sidx+1;
    if( sidx==n ) begin
        if( errs==0 ) $display("PASS (%0d samples)", n);
        else          $display("FAIL: %0d/%0d samples mismatched", errs, n);
        $finish;
    end
end

initial begin
    #40_000_000;
    $display("TIMEOUT: only %0d samples seen", sidx);
    $finish;
end

endmodule
