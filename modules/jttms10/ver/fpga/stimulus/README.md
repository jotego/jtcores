# Deterministic external-stimulus sequencer

`jttms10_fpga_stimulus.v` is the preloaded event sequencer for the next FPGA
batch protocol. It is not yet connected to the version 3 runner. The current
physical image therefore still has no IRQ/NMI/HOLD schedule support.

The block drives the existing CPU boundary: active-low LINT1/LINT2, HOLD,
emulation RUN, CEN and synchronous host HSTCTL writes. NMI/NMIM/HLT use the
ordinary host-control high byte. It does not inject the internal CPU IRQ or
NMI signals. Programs must configure the interrupt enables and vectors.

Sixteen 64-bit entries occupy a synchronous table RAM. Entries are loaded only
while unarmed. The entry count is latched before arming; later configuration
changes cannot alter it. The caller must preload and validate the complete
table before releasing the CPU. During a case, the FPGA supplies the relative
clock and actual bus/decode/acknowledgement observations. Linux supplies none
of these signals. Outputs change at falling edges, before the CPU sample edge.

| Bits | Entry field |
| --- | --- |
| 31:0 | Trigger argument |
| 47:32 | Control |
| 50:48 | Trigger type |
| 63:51 | Reserved zero |

| Trigger | Argument |
| --- | --- |
| 0 | Exact instruction-relative input clock, including zero |
| 1 | Completed physical RAM-write count, starting at one |
| 2 | Accepted decode PC, aligned to 16 bits |
| 3 | Input clocks after the previous applied event, starting at one |
| 4 | Sampled clocks with HOLD acknowledged, starting at one |
| 5 | Registered host acknowledgements, starting at one |

Control bits 0/1 assert LINT1/LINT2, 2 asserts HOLD, 3 lowers emulation RUN,
4 issues one host-control write, and 5 lowers CEN. Bits 8/9/15 supply the
HSTCTL NMI/NMIM/HLT high-byte value when bit 4 is set; all other bits are
reserved. Each event replaces the persistent pin levels. Host writes are
one-clock requests and require a low request cycle between writes. Their
registered acknowledgement is checked. Nonzero host data without a write
strobe fails explicitly.

The caller defines relative clock zero as the falling edge following the
measured opcode acceptance, matching the existing pause contract. The table
read is prefetched on rising edges, so successive entries may apply on
successive falling edges. An expired clock/count event fails; it is never
silently applied late. An unmatched PC/ack event remains pending. The caller
must fail a case if it ends with unapplied entries or outstanding host work,
and must implement the case timeout. The sequencer retains counts and event
observations after disarm until the next case's clear. Malformed events set a
sticky error and release the external pins; the caller must reject the case.

External LINT synchronizers and HSTCTL acceptance add their normal hardware
latency. A pin event after a destination write is not equivalent to asserting
an internal IRQ on that same edge. Integration tests must exercise the real
system boundary and account for that latency; they must not reuse the direct
word-bench's internal-IRQ checkpoint count as an external-pin expectation.

Run the eighteen short, literal clock/pin/handshake/negative/isolation checks:

```sh
bash modules/jttms10/ver/sim.sh fpga-stimulus
python3 modules/jttms10/ver/fpga/check_stimulus.py --report stimulus-mutations.json
```

The normal runner invokes both. Mutation checks require a passing control and
reject an early IRQ event and a wrong NMI data bit. These are Verilator checks
of the sequencer, not proof of batch-protocol integration, FPGA timing closure
or physical CPU interrupt behavior. The independent instruction expectations
remain owned by the timing suite.
