`timescale 1ns/1ps

module stim(
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL,
    output          LVBL,
    output          rom_ready
);

// initial begin
//     #240_000 $finish;
// end

reg SDRAM_CLK,  // 96   MHz
    clk=1'b0,        // 24   MHz
    cen6=1'b1,       //  6   MHz
    rst;
wire flip = 1'b0;

integer rst_cnt=0;

always @(negedge SDRAM_CLK)
    if(rst_cnt<10) begin
        rst <= 1'b1;
        rst_cnt <= rst_cnt+1;
    end
    else rst <= 1'b0;

initial begin
    SDRAM_CLK = 1'b0;
    forever SDRAM_CLK = #5.208 ~SDRAM_CLK;
end

reg [1:0] cnt24=2'd0;

always @(posedge SDRAM_CLK) begin
        cnt24 <= cnt24+2'b1;
        clk   <= cnt24 == 2'd3;
    end

reg [1:0] cnt6=2'd0;
always @(negedge clk) begin
        cnt6 <= cnt6+2'b1;
        cen6 <= cnt6==2'd3;
    end

integer lines=0;
always @(posedge LHBL) begin
    lines <= lines+1;
    if( lines == 256 )
        $finish;
end

test uut(
    .rst        ( rst       ),
    .SDRAM_CLK  ( SDRAM_CLK ),
    .clk        ( clk       ),  // 24 MHz
    .cen6       ( cen6      ),  //  6 MHz
    .flip       ( flip      ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .rom_ready  ( rom_ready )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars(1,uut);
    $dumpvars(1,uut.u_video);
    $dumpvars(1,uut.u_video.u_char);
    $dumpvars(1,uut.u_video.u_colmix);
    //$dumpvars;
    $dumpon;
end

endmodule // stim