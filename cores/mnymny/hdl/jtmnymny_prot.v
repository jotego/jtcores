/*  jtmnymny_prot.v — protection PAL16L8 at 1A on the ROM board (1B11147)
    Direct transcription of the dumped equations: see doc/pld/equations.md.
    Drives DBB4-7 on reads of 6400-65FF / 6C00-6DFF; undriven bits return 0
    (open bus, matching MAME's traced constants).
    GPL3 — see jtcores LICENSE
*/

module jtmnymny_prot(
    input      [14:0]   A,
    input               rd_n,
    input               rfsh_n,
    output     [ 7:4]   dout
);

// read strobes per the dumped OE terms (AB11 low = 6400, high = 6C00)
wire rdp  = !A[9] && A[10] && !A[12] && A[13] && A[14] && !rd_n;

// at 6C00 only offset 4 drives the high bits (board-traced; the brute-forced
// 22V10 dump over-drives D6/D7 there and breaks coin acceptance)
wire off4 = A[2] & ~A[1];
wire d4oe = rdp & ~A[11] & rfsh_n;
wire d5oe = rdp & ~A[11] & rfsh_n;
wire d6oe = rdp & (~A[11] | off4) & rfsh_n;
wire d7oe = rdp &  A[11] & off4;

wire d4 = ~(A[1]^A[2]);              // o21 = AB1 xnor AB2
wire d5 = A[2];                      // o22
wire d6 = ~(~A[1] & A[2] & A[11]);   // o23
wire d7 = 1'b1;                      // o16, constant when enabled

assign dout = { d7oe & d7, d6oe & d6, d5oe & d5, d4oe & d4 };

endmodule
