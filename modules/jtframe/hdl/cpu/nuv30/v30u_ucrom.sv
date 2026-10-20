//============================================================================
//
//  v30u_ucrom - the two build-time microcode tables (U0 finding F1).
//
//  The die holds a MATCH PLA feeding a 1028-row microcode ROM.  U0 flattened
//  the 257 activation patterns at BUILD time, which -- F1 -- is TWO tables and
//  not one:
//
//      ucdecode   8192 x 10   {valid, bank[8:0]} indexed by the 13-bit
//                             {page[2:0], opc[7:0], rowgrp[1:0]}
//      ucrom      1028 x 29   the row word, indexed by {bank[8:0], row[1:0]}
//
//  so the RTL carries ZERO match/priority logic.  `bank` re-evaluates only
//  when {page, opc, rowgrp} changes; `row` advances every row.
//
//  THE READ IS COMBINATIONAL, ON PURPOSE.  The sequencer's `upc` is the
//  architectural flop (SS-mapped in v30u_eu.sv); the two lookups then stand on
//  its output exactly as the die's PLA + ROM stand on the micro-address
//  register.  Registering either output would insert a bubble the part does
//  not have: `loc` crosses a rowgrp boundary every four rows WITHOUT a taken
//  jump, so a registered decode would cost a clock there.
//
//  AND THE TOOL AGREES IT MAY STAY THAT WAY.  U4 pass 1 read Quartus's
//  `Info (276007) ... uninferred due to asynchronous read logic` as the cause
//  of the 32,534-cell EU and called for a registered ROM.  Pass 2 MEASURED it
//  instead: these two tables, read exactly as below off a registered 15-bit
//  micro-address, cost 1,120 logic cells standalone and 1,026 in the design --
//  3 % of the EU, not 60 %.  The area was the UNROLLED CHAIN in v30u_eu.sv
//  (ucore_provenance.md sec.51), and the read stays combinational because it
//  is what the part does.
//
//  NOTE: the word "synthesis" followed by an identifier inside a comment is
//  parsed by Quartus as a PRAGMA -- sec.50.4's `Warning (10335): Unrecognized
//  synthesis attribute "shape"` came from a COMMENT on this line.  Harmless
//  there, silent and not harmless if the next word is a real attribute name.
//
//  Provenance: hdl/rtl/ucore/ucrom.hex / ucdecode.hex, emitted by
//  sw/gen_ucore_tables.py and gated byte-for-byte against the C++ model by
//  sw/check_ucore_tables.py (G0).
//
//============================================================================

module v30u_ucrom #(
    // The tables live next to the RTL, and the two tools run from DIFFERENT
    // working directories, so the default is picked per tool rather than left
    // for a project to remember to override (F44: forgetting yielded two
    // warnings, an all-zero ROM, and a run that completed normally).
    //   simulation  cwd = the repo ROOT   (sw/check_core.py, sw/ulockstep.py)
    //   Quartus     cwd = hdl/            (hdl/nec_test.qpf)
`ifdef SYNTHESIS
    parameter string HEXDIR = "rtl/ucore/"
`else
    parameter string HEXDIR = "hdl/rtl/ucore/"
`endif
) (
    // 13-bit micro-address {page[2:0], opc[7:0], rowgrp[1:0]}
    input      [12:0] dec_addr,
    output            dec_valid,
    output      [8:0] dec_bank,

    // {bank[8:0], row[1:0]}
    input      [10:0] rom_addr,
    output     [28:0] rom_word
);

// `ucdecode` is TWELVE bits wide for a TEN-bit word, and that is deliberate:
// `ucdecode.hex` carries three hex digits (a 10-bit value has no shorter hex
// form), and against a `[9:0]` target Quartus emitted `Warning (10230):
// truncated value with size 12 to match size of target (10)` on EVERY ONE of
// its 8,192 lines -- 8,192 warnings burying the map log (sec.50.4).  Bits
// [11:10] are constant zero in every entry, so they cost nothing after
// synthesis, and `dec_w[9:0]` below is the word.
reg [11:0] ucdecode [0:8191];
reg [28:0] ucrom    [0:1027];

initial begin
    $readmemh({HEXDIR, "ucdecode.hex"}, ucdecode);
    $readmemh({HEXDIR, "ucrom.hex"}, ucrom);
end

`ifndef SYNTHESIS
//----------------------------------------------------------------------------
// F44 -- THE SILENT-EMPTY FAILURE MODE, CLOSED.
//
// A wrong HEXDIR yields two `$readmemh` WARNINGS, an all-zero microcode ROM,
// and a run that COMPLETES NORMALLY -- measured, U3.  A core whose entire
// architecture is two tables must not be allowed to run without them, and a
// warning in a build log is not a gate.  So: probe both tables after the load
// and take the run down if either did not arrive.
//
// Four probes, and each one catches a different thing:
//   ucrom[0], ucdecode[0]  -- the file is ABSENT or EMPTY (nothing loaded)
//   ucrom[1027]            -- the file is SHORT (the tail never arrived);
//                             1027 is the last row and it is non-zero
//   ucdecode[0x1E43]       -- likewise for the decode table: its LAST VALID
//                             entry (the last one with the valid bit set --
//                             its literal last address is a legitimate 0x000,
//                             so probing that would prove nothing)
// The test is "did anything load here", NOT "is this the expected word": the
// CONTENT is already gated byte-for-byte against the C++ model's own parse by
// sw/check_ucore_tables.py (G0, 9,988 checks), and pinning words here would
// only add a second place to update when the tables are regenerated.
// `!==` so an X (an unwritten Verilator array) fails exactly as a 0 does.
//
// A SEPARATE `initial` FROM THE `$readmemh` ONE, AND `ifndef SYNTHESIS`.  The
// load block has to stay a bare sequence of $readmemh calls or Quartus can
// decline to infer the M10Ks and build 91,732 bits out of registers instead --
// which would be a far worse outcome than the bug being guarded against.  The
// SYNTHESIS side of F44 is therefore not this assertion: it is the `ifdef`ed
// HEXDIR above plus verifying the INITIALISED CONTENTS in the post-fit
// netlist, which is what ucore_provenance.md sec.45.4 item 2 asks for.
//----------------------------------------------------------------------------
initial begin
    #0;   // after the load block, whatever order the two are elaborated in
    if (ucrom[0] === 29'd0 || (^ucrom[0]) === 1'bx)
        $fatal(1, "v30u_ucrom: ucrom.hex did not load from '%s' -- the ROM is EMPTY (F44)", HEXDIR);
    if (ucrom[1027] === 29'd0 || (^ucrom[1027]) === 1'bx)
        $fatal(1, "v30u_ucrom: ucrom.hex is SHORT from '%s' -- row 1027 never loaded (F44)", HEXDIR);
    if (ucdecode[13'h0000] === 12'd0 || (^ucdecode[13'h0000]) === 1'bx)
        $fatal(1, "v30u_ucrom: ucdecode.hex did not load from '%s' -- the decode table is EMPTY (F44)", HEXDIR);
    if (ucdecode[13'h1E43] === 12'd0 || (^ucdecode[13'h1E43]) === 1'bx)
        $fatal(1, "v30u_ucrom: ucdecode.hex is SHORT from '%s' -- the last valid entry (0x1E43) never loaded (F44)", HEXDIR);
end
`endif

wire [9:0] dec_w = ucdecode[dec_addr][9:0];

assign dec_valid = dec_w[9];
assign dec_bank  = dec_w[8:0];
assign rom_word  = ucrom[rom_addr];

endmodule
