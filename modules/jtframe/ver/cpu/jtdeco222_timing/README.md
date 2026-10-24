# DECO222 opcode profile assessment

This simunit exhaustively checks all 256 input bytes with `opdec` low and high
(512 transform comparisons), then checks opcode-vs-operand behavior, public
bus writes, and the 14 additional NOP encodings declared by the local DECO222
profile. It also runs two bounded interrupt paths with opcode decryption held
enabled through the encrypted handler and RTI return. The repository does not
name an exact DECO vendor part or provide an original DECO timing manual, so
this suite does not claim complete original-silicon fidelity.

The IRQ and NMI cases use raw `$38` for decrypted CLI `$58`, raw `$C9` for
handler LDA-immediate `$A9`, raw `$20` for RTI `$40`, and raw immediate `$40`.
The operand remains `$40`; the handler loads `$40`. IRQ reaches vector `$2000`
with saved PC `$1002`, nine cycles from the accepted NOP boundary (the NOP's
two cycles plus seven service cycles). NMI reaches `$2100` with saved PC `$1001`
in seven cycles from that boundary. Both check the six-cycle RTI interval (24
CEN edges) to the saved return address, then execute a public `STA $42` and
accept its `$EA` successor; NMI also executes the resumed `$1001` NOP. Vector
and handler decode, stack PC, operand/result, RTI decode, and return-path bus
effect are asserted. These measurements use the shared WDC 65C02-family
comparison and tested CPU sequence; they are not independent DECO222 interrupt
timing specifications. The shared CPU's status-bit findings remain in the
65C02 assessment and are not treated as DECO-specific compatibility claims.
The local `deco222.yaml` supplies the additional NOP length/cycle expectations.
For example, it declares `$5C` as a 3-byte/4-cycle NOP, whereas WDC's reserved
opcode table gives 3 bytes/8 cycles. Those profile expectations remain
separate; no original DECO-specific NOP manual is claimed.

Run from the repository root:

```sh
source ./setprj.sh && simunit.sh --run modules/jtframe/ver/cpu/jtdeco222_timing
```

Evidence and scope limits are recorded in `tasks/jtcores-151/artifacts/deco222-result.md`.
