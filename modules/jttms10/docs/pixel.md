# Pixel-processing helper

`jttms10_pixel.v` processes one right-justified pixel for the microcoded
graphics instructions. Inputs `source_pixel` and `dest_pixel` contain the raw
low PSIZE bits. `psize` is the bit count 1, 2, 4, 8, or 16; `ppop` is
CONTROL[14:10]. `src_addr_lo` and `dst_addr_lo` are the low four **bit-address**
bits of the aligned source and destination pixels. A caller handles memory
field extraction, address conversion, windowing, and the surrounding word
read/modify/write. For a direct `PIXT Rs,*Rd` source, pass the low PSIZE bits
of Rs and set `source_is_register=1`. COLOR register patterns for FILL/DRAV/
LINE must be selected by the caller before this helper.

The 1988 TI TMS34010 User's Guide, CONTROL PPOP table (printed pp. 6-13–6-14)
and graphics §§7.5–7.7 (pp. 7-11–7-16), defines 16 bitwise Boolean operations
for all five pixel sizes and six unsigned arithmetic operations only for
4/8/16-bit pixels. `valid` is false for reserved PPOP 22–31, arithmetic at
1/2 bits, or a nonstandard PSIZE. Invalid combinations have `write_mask=0`
and preserve `dest_pixel` in `write_pixel`.

The guide's PIXT register-to-memory descriptions (pp. 12-213 and 12-215)
explicitly say the source is the **1, 2, 4, 8, or 16 least-significant bits**
of Rs. Section 7.6 (p. 7-13) says register-origin source pixels are unmodified
by PMASK, whereas memory-source and memory-destination pixel reads clear the
protected bits before PPOP. `visible_source` is this source value after size
selection and any memory-source plane mask; it is also the value to load into
a PIXT memory-to-register destination, zero-extended by the caller. The
destination mask is selected independently at `dst_addr_lo`.

`result_pixel` is the PPOP result within PSIZE. PMASK then clears protected
result bits, **before** the transparency test. `transparent` is asserted if
CONTROL.T is set and that masked result is zero. `write_mask` marks the bits
that may be changed (zero for a transparent pixel); `write_pixel` merges the
new result with the original destination under that mask. The surrounding
memory writer must preserve all other word bits. This ordering follows TI
§§7.5–7.7 and matches the old GPL `tms34010_core.sv` pixel merge path.
PPOP 9 still requires memory cycles even though its result is unchanged
(TI p. 6-13). A zero plane-write mask alone does not authorize the caller to
remove an architectural transfer; transaction sequencing belongs to microcode.

The helper does not contain an adder or subtractor. It exposes zero-extended
`alu_a=visible_source`, `alu_b=masked destination`, and `alu_op` for the
shared `jttms10_alu`; `alu_req` identifies operations that need that path,
and the caller routes back `alu_result` and `alu_borrow`.
Addition serves ADD/ADDS; subtraction serves SUB/SUBS/MAX/MIN. Saturation
uses the size-limited result and ALU borrow. Boolean operations use only
bitwise gates. Graphics microcode must reserve the shared ALU for this
operation until the result is consumed.

The focused test connects the production shared ALU and compares against
independent equations across all PPOP codes, legal PSIZEs, both source types,
every aligned source/destination lane, transparency modes, fixed/random plane
masks, and explicit arithmetic saturation boundaries:

```sh
iverilog -g2005 -s test -o /tmp/jttms10-pixel-test \
  modules/jttms10/ver/pixel/test.sv \
  modules/jttms10/hdl/jttms10_pixel.v \
  modules/jttms10/hdl/jttms10_alu.v
vvp /tmp/jttms10-pixel-test
```
