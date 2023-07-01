module test;

parameter LATCH=0, REPACK=0;

reg         rst, clk;
reg  [ 7:0] addr;
wire [15:0] dout;
wire [21:0] sdram_addr;

reg [15:0] mem[0:255];
reg [31:0] din;
reg  [2:0] oksh=0;
wire       din_ok = oksh[0];
wire       req, data_ok;
wire       fail;
reg        addr_ok=1;

integer aux;

wire [ 7:0] bufa = sdram_addr[7:0];
wire        sel  = oksh[2];
wire [15:0] expected = mem[addr];

initial begin
    for( aux=0; aux<256; aux=aux+1 ) mem[aux]=$random;
    rst=1;
    addr=0;
    #44 rst=0;
end

initial begin
    clk = 0;
    forever #10 clk = ~clk;
end

always @(posedge clk) begin
    if( &oksh ) oksh<=0;
    else begin
        if( req || oksh[2] ) begin
            oksh <= {1'b1, oksh[2:1] };
        end else oksh<=0;
    end
    if( oksh[1] )
        din <= { mem[bufa+1], mem[bufa] };
    else
        din <= 32'hxx;

    if( data_ok ) begin
        addr    <= $random;
        addr_ok <= 0;
    end else addr_ok <= 1;

    if( fail ) begin
        $display("FAILED");
        #40 $finish;
    end
end

assign fail = data_ok && dout!=expected && addr_ok;

jtframe_romrq #(
    .AW     (  8        ),
    .DW     (  16       ),
    .LATCH  ( LATCH     ),
    .REPACK ( REPACK    )
) uut (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clr        ( 1'b0          ), // clears the cache
    .offset     ( 22'd0         ),
    .addr       ( addr          ),
    .addr_ok    ( addr_ok       ),    // signals that value in addr is valid
    .din        ( din           ),
    .din_ok     ( din_ok        ),
    .we         ( sel           ),
    .req        ( req           ),
    .data_ok    ( data_ok       ),    // strobe that signals that data is ready
    .sdram_addr ( sdram_addr    ),
    .dout       ( dout          )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    #40000;
    $display("PASS");
    $finish;
end

endmodule