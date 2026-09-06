/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later */

// jtmnymny_prot.v — protection PAL16L8 at 1A on the ROM board (1B11147)
// Direct transcription of the dumped equations: see doc/pld/equations.md.
// Drives DBB4-7 on reads of 6400-65FF / 6C00-6DFF; undriven bits return 0
// (open bus, matching MAME's traced constants).

module jtmnymny_prot(
    input               jackrabt,
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

wire [7:4] mm_dout = { d7oe & d7, d6oe & d6, d5oe & d5, d4oe & d4 };

// Jack Rabbit PAL is undumped (read protected); constants traced in MAME
reg  [7:4] jr_dout;
always @* begin
    jr_dout = 0;
    if( rdp ) case( {A[11], A[2:0]} )
        4'b0_000: jr_dout = 4'h5;   // 6400 -> 50
        4'b0_100: jr_dout = 4'h4;   // 6404 -> 40
        4'b0_110: jr_dout = 4'ha;   // 6406 -> A0
        4'b1_010: jr_dout = 4'h1;   // 6C02 -> 10
        4'b1_100: jr_dout = 4'h8;   // 6C04 -> 80
        default:  jr_dout = 0;
    endcase
end

assign dout = jackrabt ? jr_dout : mm_dout;

endmodule
