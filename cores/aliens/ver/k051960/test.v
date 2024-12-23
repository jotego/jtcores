`timescale 1ns/1ps

module test;

reg  nRES;
reg  clk_24M, clk_48M, clk_96M;
reg  NRD;      // CPU read
reg  OBCS;

// CPU interface
reg  [ 7:0] DB_IN=0;
reg  [10:0] AB=0;

// External RAM interface
reg  [ 9:0] OA_in=0;
wire [ 7:0] OD_in;

wire RST, clk_6M, clk_12M, P1H, P2H, HVOT,
     PQ, PE,  // 6809
     WRP, WREN, RDEN,
     IRQ, FIRQ, NMI,
// k051937 interface
     OHF, OREG, HEND, LACH, CARY,
     OWR, OOE, HVIN,
     DB_DIR;
wire [8:0] HP;    // X position
wire [7:0] OC,    // Attributes
           OD_out,
           DB_OUT;
// GFX ROMs interface
wire [17:0] CA;
wire [9:0] OA_out;

reg [7:0] ram[0:1023];

integer aux, rdcnt;

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

initial begin
    aux = $fopen("obj.bin","rb");
    if( aux==0 ) begin
        for( aux=0; aux<1024; aux=aux+1 ) begin
            ram[aux] = 0;
        end
    end else begin
        rdcnt=$fread(ram,aux);
        $fclose(aux);
        $display("Read %d bytes from obj.bin",rdcnt);
    end
end

assign OD_in = ram[OA_out];

always @* begin
    if( ~OWR ) ram[OA_out] = OD_out;
end

initial begin
    { clk_24M, clk_48M, clk_96M } = 0;
    forever #5.208 { clk_24M, clk_48M, clk_96M }={ clk_24M, clk_48M, clk_96M }+3'd1;
end

initial begin
    nRES  = 0;
    OBCS  = 1;
    NRD   = 0;
    DB_IN = 0;
    repeat(10) @(posedge clk_24M);
    nRES=1;
    repeat(100) @(posedge clk_24M);
    repeat(4) @(negedge PE) begin
        OBCS = 0;
        AB = ~11'h7;
        DB_IN = 8'h10;
        NRD = 1;
    end
    NRD = 0;
    repeat(10_000) @(negedge PE) begin
        // OBCS = 0;
        // { AB[15:11], NRD } = {AB[15:11], NRD} + 1'd1;
        repeat(8) @(negedge PE) begin
            OBCS = 1;
        end
    end
    $finish;
end

k051960 uut(
    .nRES       ( nRES      ),
    .RST        ( RST       ),
    .clk_24M    ( clk_24M   ),
    .clk_6M     ( clk_6M    ),
    .clk_12M    ( clk_12M   ),

    .P1H        ( P1H       ),
    .P2H        ( P2H       ),
    .HVIN       ( HVIN      ),
    .HVOT       ( HVOT      ),    // Frame sync tick

    .PQ         ( PQ        ),
    .PE         ( PE        ),  // 6809

    .WRP        ( WRP       ),
    .WREN       ( WREN      ),
    .RDEN       ( RDEN      ), // ? Unused
    .NRD        ( NRD       ),      // CPU read
    .OBCS       ( OBCS      ),
    .IRQ        ( IRQ       ),
    .FIRQ       ( FIRQ      ),
    .NMI        ( NMI       ),

    // CPU interface
    .DB_IN      ( DB_IN     ),
    .DB_OUT     ( DB_OUT    ),
    .AB         ( AB        ),

    // k051937 interface
    .OHF        ( OHF       ),
    .OREG       ( OREG      ),
    .HEND       ( HEND      ),
    .LACH       ( LACH      ),
    .CARY       ( CARY      ),
    .HP         ( HP        ),    // X position
    .OC         ( OC        ),    // Attributes

    // GFX ROMs interface
    .CA         ( CA        ),

    // External RAM interface
    .OA_in      ( OA_in     ),
    .OA_out     ( OA_out    ),
    .OWR        ( OWR       ),
    .OOE        ( OOE       ),
    .OD_in      ( OD_in     ),
    .OD_out     ( OD_out    ),

    .DB_DIR     ( DB_DIR    )
);

k051937 u_draw(
    .clk_96M    (           ),

    .nRES       ( nRES      ),
    .clk_24M    ( clk_24M   ),

    .P1H        (           ),
    .P2H        (           ),

    .HVIN       ( HVIN      ),
    .HVOT       (           ),

    .NRD        ( 1'b0      ),
    .OBCS       ( 1'b1      ),

    .AB         ( 3'd0      ),
    .AB10       ( 1'd0      ),

    .DB_OUT     (           ),
    .DB_IN      (   8'd0    ),

    .NCSY       (           ),
    .NVSY       (           ),
    .NHSY       (           ),
    .NCBK       (           ),
    .NVBK       (           ),
    .NHBK       (           ), // blanking signals, CBK = combined V/H blanking
    .SHAD       (           ),
    .NCO0       (           ),
    .PCOF       (           ),
    .OB         (           ),

    // Bitplanes in
    .CD0        (   8'd0    ),
    .CD1        (   8'd0    ),
    .CD2        (   8'd0    ),
    .CD3        (   8'd0    ),

    .CAW        (           ),

    .OC         ( OC        ),
    .HP         ( HP        ),

    .CARY       ( CARY      ),
    .LACH       ( LACH      ),
    .HEND       ( HEND      ),
    .OREG       ( OREG      ),
    .OHF        ( OHF       ),

    .DB_DIR     (           )
);

k052109 u_k052109(
    .nRES       ( nRES      ),
    .RST        ( RST       ),
    .clk_24M    ( clk_24M   ),

    .clk_12M    ( ),

    .CRCS       ( 1'b1 ),     // CPU GFX ROM access
    .RMRD       ( 1'b0 ),
    .VCS        ( 1'b1 ),      // CPU VRAM access
    .NRD        ( 1'b0 ),      // CPU read
    .FIRQ       ( ),
    .IRQ        ( ),
    .NMI        ( ),
    .PQ         ( ),      // 6809
    .PE         ( ),      // 6809
    .HVOT       ( HVIN      ),    // Frame sync tick
    .RDEN       ( ),    // ? Unused
    .WREN       ( ),    // ? Unused
    .WRP        ( ),     // ? Unused

    // CPU interface
    .DB_IN      ( DB_IN ),
    .DB_OUT     ( ),
    .AB         ( 16'd0    ),

    // VRAM interface
    .VD_OUT     ( ),
    .VD_IN      ( 16'd0 ),
    .RA         ( ),
    .RCS        ( ),
    .ROE        ( ),
    .RWE        ( ),

    // GFX ROMs interface
    .CAB        ( ),
    .VC         ( ),

    .VDE        ( ),

    // k051962 interface
    .COL        ( ),               // Tile COL attribute bits
    .ZA1H       ( ),
    .ZA2H       ( ),
    .ZA4H       ( ),
    .ZB1H       ( ),
    .ZB2H       ( ),
    .ZB4H       ( ),

    .BEN        ( ),     // Reg 1E80 write

    .DB_DIR     ( )
);


endmodule