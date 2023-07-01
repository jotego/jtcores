`timescale 1ns / 1ps

module test;

integer file, fcnt;

reg  [ 7:0] coded[0:32767];

reg  [31:0] key_data[0:3];
wire [31:0] swap_key1, swap_key2;
wire [15:0] addr_key;
wire [ 7:0] xor_key;

wire [ 7:0] dec_data, dec_op, din;

reg  [14:0] addr;
reg         clk;

assign swap_key1 = key_data[0];
assign swap_key2 = key_data[1];
assign addr_key  = key_data[2][15:0];
assign xor_key   = key_data[3][7:0];

initial begin
    $readmemh( "keys.hex", key_data );
    file=$fopen("coded.bin","rb");
    if( file==0 ) begin
        $display("ERROR: cannot read coded.bin");
        $finish;
    end
    fcnt = $fread(coded, file, 0, 32768);
    if( fcnt!=32768 ) begin
        $display("ERROR: only %d bytes read from file. Expecting 32kB", fcnt);
        $finish;
    end
    $fclose(file);
end

initial begin
    clk  = 0;
    addr = 15'd0;
    forever #10 clk = ~clk;
end

assign din = coded[addr];

always @(posedge clk) begin
    addr <= addr + 1;
    $display("%02X %02X", dec_op, dec_data);
    if( &addr ) $finish;
end

jtframe_kabuki u_decdata(
    .rst_n      ( 1'b1      ),
    .clk        ( 1'b1      ),
    .m1_n       ( 1'b1      ),
    .rd_n       ( 1'b0      ),
    .mreq_n     ( 1'b0      ),
    .addr       ( {1'b0,addr} ),
    .din        ( din       ),
    // Decode keys
    .swap_key1  ( swap_key1 ),
    .swap_key2  ( swap_key2 ),
    .addr_key   ( addr_key  ),
    .xor_key    ( xor_key   ),
    .dout       ( dec_data  )
);

jtframe_kabuki u_decop(
    .rst_n      ( 1'b1      ),
    .clk        ( 1'b1      ),
    .m1_n       ( 1'b0      ),
    .rd_n       ( 1'b0      ),
    .mreq_n     ( 1'b0      ),
    .addr       ( {1'b0,addr} ),
    .din        ( din       ),
    // Decode keys
    .swap_key1  ( swap_key1 ),
    .swap_key2  ( swap_key2 ),
    .addr_key   ( addr_key  ),
    .xor_key    ( xor_key   ),
    .dout       ( dec_op    )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end

endmodule