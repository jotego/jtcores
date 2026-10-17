# NARC abstract-cycle arbiter

`jttms10_bus.v` connects a `jttms10_word` physical 16-bit client, the held
screen-refresh and host-indirect requests from `jttms10_io`, and the one-clock DRAM-refresh event
to the existing NARC `cyc_*` interface. It uses the TMS34010 priority from the
1988 TI User's Guide §11.3: HOLD, screen refresh, DRAM refresh, host, then CPU.
The old GPL `modules/tms34010/rtl/memory/tms34010_bus_arbiter.sv` informed the
cycle kinds and partial-word reservation rule. The synchronous host-register
and indirect client are described in [host.md](host.md); physical asynchronous
host-pin timing remains outside this fabric.

`jttms10_fabric.v` connects this arbiter and the I/O/video/refresh block while
keeping a physical-word client interface independent of the CPU. Its
`ver/fabric/test.sv` bench uses the actual field adapter and a waiting NARC
cycle model. It checks a 24-bit I/O field spanning two registers, partial-word
preservation and one commit per write, I/O readback, HOLD with an external
memory change, delayed screen completion, and a REFCNT-generated refresh.
The standard `ver/run.sh` and `ver/lint.sh` include this integration boundary.

`word_addr` is a 32-bit **bit** address. The field adapter holds `word_req`,
`word_we`, address, and data until `word_ack`, which the arbiter generates for
one clock when NARC acknowledges the selected cycle. `word_req` may remain
high as the field adapter advances from a partial-word read to its write or
to another physical word. The arbiter detects the changed physical request
tuple at that boundary and will not issue the previous identical tuple again
while `word_req` is held. A caller that intends a second *identical* physical
cycle must lower `word_req` for a clock between them. This matches the current
field adapter's request progression; if that progression changes, revisit this
boundary contract. `word_rdata` is `cyc_rdata`, valid with `word_ack`.

The selected kind and all payload fields are latched before `cyc_req` rises
and remain stable until `cyc_ack`. Kind 0/1 are normal word read/write; 2 is
screen refresh with held raw SRFADR, DPYTAP, and ORG; 3/4 are RAS/CBR DRAM
refresh; 5/6 are I/O read/write; 7/8 are pixel MTR/RTM when the physical
request's `word_pixel` tag and `pixel_srt` are both set. I/O classification
has priority over the pixel tag. The internal `io_rdata` is sampled at grant
for a stable kind-5 payload, and IAQ is suppressed on I/O and pixel cycles.
The external NARC controller still supplies a timed acknowledgement for I/O
cycles; the peripheral register write must commit on the resulting
`word_ack`. `cyc_dram_row` may be left unused by the NARC board bridge, as in
the old wrapper.

`word_lock` reserves the bus after a partial-word read is selected, so its
matching write beats screen and DRAM traffic. HOLD cannot interrupt an active
cycle. At the idle boundary between the read and its write, HOLD wins and
pulses `word_restart` for one clock; `jttms10_field` then suppresses its stale
write, drops the lock, and rereads the word after HOLD releases. HOLD accepted
after write completion has no restart. See [field.md](field.md) for the
adapter-side contract.

The DRAM refresh event is captured with row/mode even when a higher-priority
client owns the bus. There is one pending slot in addition to an active DRAM
cycle. Further refresh pulses while that slot is occupied coalesce to the
latest row/mode; the bus cannot guarantee every refresh if the external
controller stalls longer than the programmed refresh interval. Screen requests
must stay asserted through their acknowledgement. A served-screen flag stops
a delayed deassertion from producing a duplicate physical cycle.

Standalone directed verification covers wait-state payload stability,
priority with competing clients, held acknowledgements/requests, queued DRAM
events, I/O and pixel kind selection, IAQ suppression, and HOLD before and
after the partial-write boundary:

```sh
iverilog -g2012 -s test -o /tmp/jttms10bus-test.vvp \
    modules/jttms10/ver/bus/test.sv modules/jttms10/hdl/jttms10_bus.v
vvp /tmp/jttms10bus-test.vvp
verilator --lint-only -Wall --top-module jttms10_bus \
    modules/jttms10/hdl/jttms10_bus.v
```
