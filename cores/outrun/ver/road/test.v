`timescale 1ns / 1ps

/*
Schematics, CPU board, page 6/7

SEGA-315-5225.jed  Sega_315-5226_GAL16V8_IC79.jed
[rom/outrun (outrun)]$ jedutil -view  Sega_315-5226_GAL16V8_IC79.jed GAL16V8
Inputs:

2, 3, 4, 5, 6, 7, 8, 9, 12, 13, 14, 15, 16, 17, 18, 19

Outputs:

14 (Registered, Output feedback registered, Active high)
15 (Registered, Output feedback registered, Active high)
16 (Registered, Output feedback registered, Active low)
17 (Registered, Output feedback registered, Active low)
19 (Combinatorial, Output feedback output, Active high)

Equations:

rf14 := /i8 & /i12
rf14.oe = OE

rf15 :=
rf15.oe = OE

/rf16 := i6 & /i7 & /i8 & i9 & /i12 +
         /i3 & /i6 & i7 & /i8 & i9 & /i12 +
         /i4 & /i6 & i7 & /i8 & i9 & /i12 +
         /i5 & /i6 & i7 & /i8 & i9 & /i12 +
         i3 & i4 & i5 & /i7 & /i8 & i9 & /i12
rf16.oe = OE

/rf17 := i2 & i3 & /i4 & /i5 & i6 & i13
rf17.oe = OE

o19 = rf17 & i18
o19.oe = vcc

-----------------------------------------------

jedutil -view SEGA-315-5225.jed GAL16V8
Inputs:

2, 3, 4, 5, 6, 7, 8, 9, 12, 13, 14, 15, 16, 17, 18, 19

Outputs:

14 (Registered, Output feedback registered, Active high)
15 (Registered, Output feedback registered, Active high)
16 (Registered, Output feedback registered, Active low)
17 (Registered, Output feedback registered, Active low)
18 (Combinatorial, Output feedback output, Active low)
19 (Combinatorial, Output feedback output, Active low)

Equations:

rf14 :=
rf14.oe = OE

rf15 := /rf15 +
        /i2 +
        i4 +
        i7 +
        /i12
rf15.oe = OE

/rf16 := /i2 & /i4 & /i7 & i12
rf16.oe = OE

/rf17 := /i2 & /i3 & /i4 & /i5 & /i6 & /i7 & i8 & i13 +
         /i2 & /i3 & /i4 & /i5 & /i6 & /i7 & i9 & i13
rf17.oe = OE

/o18 = /rf17
o18.oe = vcc

/o19 = /rf16
o19.oe = vcc

*/

/*
  Findings:
  H count goes from $85 to $213 = 63.5624 us -> 15.73 kHz
  HB goes from $201 to $C1 = 12.71 us
  HS goes from $8F to $AF  = 5.08 us
  /IPL1 goes low at v == 64,128 and 192 synchronized with hblank
  V count goes from 0 to 222, then jumps to 474 with /GXINT
  That's assuming a 60.05Hz /GXINT signal. Presumably the 474-511
  section matches VBLANK (2.41ms)

  At the beginning of VBLANK (marked by /GXINT), the road stop signal
  is set for one line. For the next line, the /RDHON signal toggles
  at each clock cycle

  Two signals synchronized this counter with the tile generator:
  - CLD, clears the H counter and should be needed only at boot time
  - /GXINT, clears the v counter and is needed once per frame

*/
module test;

reg clk, ven_n=0, hblank=0, hbl=0, hsync=0;
reg [9:0] h;
reg [8:0] v=9'h1da;
wire      gxint_n = v!=9'hdf;
reg       ilp1_n, rdstop_n, rdhon_n;

initial begin
    clk = 0;
    forever #79.453 clk = ~clk; // 6.293 MHz
end

always @(posedge clk, negedge ven_n) begin
    if( !ven_n ) begin
        h <= 10'h85;
    end else begin
        h <= h + 1'd1;
    end
end

always @(posedge hblank, negedge gxint_n) begin
    if( !gxint_n ) begin
        v <= 9'h1da;
    end else begin
        v <= v + 1'd1;
    end
end

// 315-5226
always @(posedge clk) begin
    ven_n <= ~( h[4:0]==5'b10011 & h[9] );
    hblank <= ~h[6] & ~h[8];
    hsync  <= !( (!h[8] && h[7] && !h[6]) && (
             h[5:4] == 2'b01 ||
            (h[5:4] == 2'b10 && !h[1]) ||
            (h[5:4] == 2'b10 && !h[2]) ||
            (h[5:4] == 2'b10 && !h[3]) ||
            (!h[5] && h[3:1]==3'b111 )
        ));
end

// 315-5225
always @(posedge clk) begin
    ilp1_n   <= !(v[5:0]==0 && hblank && (v[7] || v[6]));
    rdstop_n <= !(!v[0] && !v[2] && !v[5] && v[8]);
    rdhon_n  <= !rdhon_n || !v[0] || v[2] || v[5] || !v[8];
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
    #80_000_000 $finish;
end

endmodule


module merger(
    input              clk,
    input       [11:0] addr_a,
    input       [11:0] addr_b,
    input       [11:0] v_a,
    input       [11:0] v_b,
    input       [ 1:0] ctrl,
    input              hsync,
    output      [ 4:0] rrc
);

    wire [3:0] m;
    wire       cent_a, cent_b;
    wire [1:0] rd_a, rd_b;

    draw_half half_a(
        .clk    ( clk       ),
        .addr   ( addr_a    ),
        .v      ( v_a       ),
        .hsync  ( hsync     ),
        .cent   ( cent_a    ),
        .m      ( m[1:0]    )
    );

    draw_half half_b(
        .clk    ( clk       ),
        .addr   ( addr_b    ),
        .v      ( v_b       ),
        .hsync  ( hsync     ),
        .cent   ( cent_b    ),
        .m      ( m[3:2]    )
    );

    assign {rd_b, rd_a} = m;

    localparam [1:0] ONLY_ROAD0=0, ROAD0_PRIO=1,
                     ROAD1_PRIO=2, ONLY_ROAD1=3;

    rrc[0] =  cent_a & (rd_a == 3) & !rrc[2]
        | cent_b & (rd_b == 3) & rrc[2]
        | (rd_a == 1) & !rrc[2]
        | (rd_b == 1) & rrc[2];

    rrc[1] =  cent_a & (rd_a == 3) & !rrc[2]
        | cent_b & (rd_b == 3) & rrc[2]
        | (rd_a == 2) & !rrc[2]
        | (rd_b == 2) & rrc[2];

    rrc[2] = hsync & IIQ
        | (ctrl == ONLY_ROAD1)
        | !cent_a & (rd_a == 3) & !cent_b & (rd_b == 3) & (ctrl == ROAD1_PRIO)
        | cent_b & (rd_b == 3) & (ctrl == ROAD1_PRIO)
        | !cent_a & (rd_a == 3) & !m[2] & (ctrl == ROAD1_PRIO)
        | !cent_a & (rd_a == 3) & !m[3] & (ctrl == ROAD1_PRIO)
        | !m[0] & (rd_b == 0) & (ctrl == ROAD1_PRIO)
        | !m[1] & (rd_b == 0) & (ctrl == ROAD1_PRIO)
        | !cent_a & (rd_a == 3) & cent_b & (rd_b == 3) & (ctrl == ROAD0_PRIO)
        | !m[0] & cent_b & (rd_b == 3) & (ctrl == ROAD0_PRIO)
        | !m[1] & cent_b & (rd_b == 3) & (ctrl == ROAD0_PRIO)
        | !cent_a & m[0] & (rd_b == 0) & (ctrl == ROAD0_PRIO)
        | !cent_a & m[1] & (rd_b == 0) & (ctrl == ROAD0_PRIO)
        | !cent_a & (rd_a == 3) & (rd_b == 1) & (ctrl == ROAD0_PRIO)
        | !cent_a & (rd_a == 3) & (rd_b == 2) & (ctrl == ROAD0_PRIO);

    // high when solid color is chosen
    rrc[3] =  v_a[11] & v_b[11]
        | v_a[11] & (ctrl == ONLY_ROAD0)
        | v_b[11] & (ctrl == ONLY_ROAD1);

    // selects solid color or ROM value, high when the road pixel
    // is transparent (v[11] high or rd==3)
    rrc[4] =  !cent_a & (rd_a == 3) & !cent_b & (rd_b == 3)
        | v_a[11] & v_b[11]
        | v_a[11] & (ctrl == ONLY_ROAD0)
        | v_b[11] & (ctrl == ONLY_ROAD1)
        | !cent_b & (rd_b == 3) & (ctrl == ONLY_ROAD1)
        | !cent_a & (rd_a == 3) & (ctrl == ONLY_ROAD0);
endmodule

//////////////////////////////////////////////////////////////
module draw_half(
    input              clk,
    input       [11:0] addr,
    input       [11:0] v,
    input              hsync,
    output reg         cent,
    output reg  [ 1:0] m
);

    parameter ROM="opr-10186.47"

    reg  [ 7:0] rom[0:2**15-1]; // upper half contains bit 1, lower half bit 0
    // the pixel order is from MSB to LSB (left to right)
    reg  [11:0] ff;
    wire [14:0] rom_a;
    wire [ 7:0] rom_d;
    wire        oe_cs;
    wire        ff_is_7, ff_over, k;
    wire [11:0] ff_plus1;

    integer aux;

    initial begin
        aux=$fopen(ROM,"rb");
        $fread(aux,rom);
        $fclose(aux);
    end

    always @(posedge clk) begin
        if( hsync ) begin
            ff <= addr;
        end else begin
            ff <= ff_plus1;
        end
    end

    always @(posedge clk, posedge hsync) begin
        if( hsync ) begin
            cent <= 0;
        end else begin
            case( {ff_is_7, k} )
                2'b01: cent <= 1;
                2'b10: cent <= 0;
                2'b11: cent <= ~cent;
            endcase // {ff_is_7, k}
        end
    end

    assign rom_a   = { ff[2], v[8:1], ff[8:3] };
    assign ff_over = ~ff[11] & ff[10] & ff[9];
    assign oe_cs   = ~v[11] & ff_over;
    assign rom_d   = oe_cs ? rom[ rom_a ] : 8'hff;
    assign ff_is_7 = &ff[2:0];
    assign ff_plus1= ff + 12'd1;
    assign k       = ff[7:4]==4'hf && !ff[8] && ff_over;

endmodule