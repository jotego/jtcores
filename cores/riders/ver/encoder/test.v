`timescale 1ns/1ps

module test;

parameter TIMEOUT=40_000_000;

reg         rst, clk;

wire [18:0] pscmap_addr;
reg  [18:0] pscprev;
reg  [31:0] pscmap_data=0;
wire        pscmap_ok;
wire        pscmap_cs;
reg         ok1=0;
// Compressed tilemap in VRAM
wire [17:1] vram_addr; //
wire [15:0] vram_din;
wire        vram_we;
// Decoder
wire [12:0] dec_addr;
wire [71:0] dec_din;
reg  [71:0] dec_dout;
wire        dec_we;

reg  [0:31] pscmap[0:2**19-1];
reg  [0:71] decmem[0:2**13-1];

initial begin
    $readmemh("pscmap.hex",pscmap);
end

assign pscmap_ok = pscprev == pscmap_addr && ok1;

always @(posedge clk) begin
    if(pscmap_cs) begin
        pscprev <= pscmap_addr;
        ok1     <= pscprev == pscmap_addr;
    pscmap_data <= pscmap[pscprev];
    end else begin
        ok1     <= 0;
    pscmap_data <= 0;
    end
end

always @(posedge clk) begin
    if( dec_we ) decmem[dec_addr]<=dec_din;
    dec_dout <= decmem[dec_addr];
end

always @(posedge uut.done) begin
    $display("PASS");
    $finish;
end

jtglfgreat_encoder uut(
    .rst            ( rst           ),
    .clk            ( clk           ),
    // SDRAM
    .pscmap_addr    ( pscmap_addr   ),
    .pscmap_data    ( pscmap_data   ),
    .pscmap_ok      ( pscmap_ok     ),
    .pscmap_cs      ( pscmap_cs     ),
    // Compressed tilemap in VRAM
    .vram_addr      ( vram_addr     ),
    .vram_din       ( vram_din      ),
    .vram_we        ( vram_we       ),
    // Decoder
    .dec_addr       ( dec_addr      ),
    .dec_dout       ( dec_dout      ),
    .dec_din        ( dec_din       ),
    .dec_we         ( dec_we        )
);

initial begin
    rst=0;
    #30  rst=1;
    #300 rst=0;
    #TIMEOUT
    $display("FAIL: Timeout");
    $finish;
end
initial begin
    clk=0;
    forever #10.416 clk=~clk;   // 48 MHz
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

endmodule
