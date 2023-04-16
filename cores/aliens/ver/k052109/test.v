`timescale 1ns/1ps

module test;

wire        FIRQ, IRQ,  NMI,  PQ,   clk_12M,
            PE,   HVOT, RDEN, WREN, WRP,
            VDE,  ZA4H, ZA2H, ZA1H,
            BEN,  ZB4H, ZB2H, ZB1H, DB_DIR;
wire [ 7:0] DB_OUT, COL;
wire [15:0] VD_OUT, VD_IN;
wire [12:0] RA;
wire [ 1:0] RCS;
wire [ 2:0] ROE, RWE;
wire [ 2:1] CAB;
wire [10:0] VC;

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
    repeat(100) @(posedge clk);
    repeat(20_000) @(negedge PE) begin
        VCS = 0;
        { AB[15:11], NRD } = {AB[15:11], NRD} + 1'd1;
        repeat(8) @(negedge PE) begin
            VCS = 1;
        end
    end
    $finish;
end

reg [7:0] ram1[0:8191];
reg [7:0] ram2[0:8191];

integer aux;

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

initial begin
    for( aux=0; aux<8192; aux=aux+1 ) begin
        ram1[aux] = 0;
        ram2[aux] = 0;
    end
end

assign VD_IN = {ram1[RA],ram2[RA]};

always @* begin
    if( ~RWE[2]           ) ram2[RA] = VD_OUT[ 7:0];
    if( ~RWE[1] & ~RCS[1] ) ram1[RA] = VD_OUT[15:8];
end

k052109 uut(
    .nRES       ( nRES      ),
    .RST        ( RST       ),
    .clk_24M    ( clk       ),

    .clk_12M    ( clk_12M   ),

    .CRCS       ( CRCS      ),     // CPU GFX ROM access
    .RMRD       ( RMRD      ),
    .VCS        ( VCS       ),      // CPU VRAM access
    .NRD        ( NRD       ),      // CPU read
    .FIRQ       ( FIRQ      ),
    .IRQ        ( IRQ       ),
    .NMI        ( NMI       ),
    .PQ         ( PQ        ),      // 6809
    .PE         ( PE        ),      // 6809
    .HVOT       ( HVOT      ),    // Frame sync tick
    .RDEN       ( RDEN      ),    // ? Unused
    .WREN       ( WREN      ),    // ? Unused
    .WRP        ( WRP       ),     // ? Unused

    // CPU interface
    .DB_IN      ( DB_IN     ),
    .DB_OUT     ( DB_OUT    ),
    .AB         ( AB        ),

    // VRAM interface
    .VD_OUT     ( VD_OUT    ),
    .VD_IN      ( VD_IN     ),
    .RA         ( RA        ),
    .RCS        ( RCS       ),
    .ROE        ( ROE       ),
    .RWE        ( RWE       ),

    // GFX ROMs interface
    .CAB        ( CAB       ),
    .VC         ( VC        ),

    .VDE        ( VDE       ),

    // k051962 interface
    .COL        ( COL       ),               // Tile COL attribute bits
    .ZA1H       ( ZA1H      ),
    .ZA2H       ( ZA2H      ),
    .ZA4H       ( ZA4H      ),
    .ZB1H       ( ZB1H      ),
    .ZB2H       ( ZB2H      ),
    .ZB4H       ( ZB4H      ),

    .BEN        ( BEN       ),     // Reg 1E80 write

    .DB_DIR     ( DB_DIR    )
);

endmodule