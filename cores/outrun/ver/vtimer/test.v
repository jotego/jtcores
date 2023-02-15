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