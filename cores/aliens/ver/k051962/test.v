`timescale 1ns/1ps

module test;

wire        clk_12M, clk_6M,
            VDE,  ZA4H, ZA2H, ZA1H,
            BEN,  ZB4H, ZB2H, ZB1H, DB_DIR;
wire [ 7:0] DB_OUT;

reg         nRES, clk, CRCS, RMRD, VCS, NRD;
reg  [ 7:0] DB_IN;
reg  [15:0] AB;

initial begin
    clk = 0;
    forever #20.833 clk=~clk;
end

initial begin
    nRES = 0;
    CRCS = 1;
    VCS  = 1;
    NRD  = 0;
    RMRD = 0;
    DB_IN= 0;
    AB   = 0;
    repeat(10) @(posedge clk);
    nRES=1;
    repeat(300_000) @(posedge clk_6M);
    $finish;
end

integer aux;

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

k051962 uut(
    .nRES       ( nRES      ),
    .RST        ( RST       ),
    .clk_24M    ( clk       ),

    .clk_12M    ( clk_12M   ),
    .clk_6M     ( clk_6M    ),
    .P1H        (           ),
    .VC         (32'h12345678),
    // CPU interface
    .CRCS       ( CRCS      ),     // CPU GFX ROM access
    .DB_IN      ( DB_IN     ),
    .DB_OUT     ( DB_OUT    ),
    .AB         ( AB[1:0]   ),

    // k052109 interface
    .RMRD       ( RMRD      ),
    .COL        ( 8'd0      ),               // Tile COL attribute bits
    .ZA1H       ( ZA1H      ),
    .ZA2H       ( ZA2H      ),
    .ZA4H       ( ZA4H      ),
    .ZB1H       ( ZB1H      ),
    .ZB2H       ( ZB2H      ),
    .ZB4H       ( ZB4H      ),
    .BEN        ( 1'b0      ),
    .DB_DIR     ( DB_DIR    )
);

endmodule