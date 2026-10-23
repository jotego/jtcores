# Schematic traces requested — review follow-up

Three circuits from the 2026-10-21 HDL review stayed open because the current
HDL follows MAME abstractions where no board trace exists yet. Each item lists
the nets to follow, what the HDL assumes today, and the decision that hangs on
the answer.

## 1. AY 1D port B bit 2 → MCU (4F) reset path

Trace: AY 1D port B bit 2 output pin, through any buffer/gate/RC, to the pin(s)
it reaches on the NSC81050 at 4F (reset and/or halt). Note every component in
between and any pull-up/pull-down on the line.

HDL today: `jtseicro_snd.v` models the line as idle-high (AY internal pull-up,
confirmed) and releases the MCU from reset on the first rising edge only;
`reset_req` is tied low, so later edges do nothing.

Decision: MAME pulses MCU reset on *every* rising edge of bit 2. If the board
has an edge/one-shot circuit, the core should pulse `reset_req` on later edges
too; if bit 2 drives a plain level into reset or halt, the current model (or a
level model) is right and MAME is the approximation.

Also useful: whether the drawn 3.3k external pull-ups cover port B pins or only
port A, for the idle level before the game first drives the port.

## 2. Z80 INT generation and clear

Trace: the flip-flop or gate chain that asserts the Z80 /INT at vertical blank,
and everything that can clear it — interrupt acknowledge (/IORQ together with
/M1), the AY port B bit 0 enable, a counter, or the next blanking edge. Note
where bit 0 gates the chain (at the set input, the output, or the clear).

HDL today: `jtseicro_main.v` sets `irq_pending` at the vblank edge when bit 0
is high and clears it only when bit 0 drops (or reset). There is no clear on
interrupt acknowledge.

Decision: MAME uses HOLD_LINE (auto-clear on acknowledge). The supported sets
work either way because they toggle bit 0 every frame, but unverified sets or
service paths may hold bit 0 high; the real clear source settles whether an
acknowledge clear belongs in the HDL.

## 3. Watchdog counter

Trace: the watchdog circuit — the counter IC and its location, its clock
source (vertical blank?), its clear input (the 0xB800 read decode and the
service switch), which count taps drive the reset, and the shape of the reset
output (one-shot or held).

HDL today: `jtseicro_watchdog.v` assumes a 4-bit counter of vblanks, reset
asserted at count 15, cleared by the 0xB800 read or service. That is ~0.27 s.

Decision: MAME uses its generic 3-second default, which is almost certainly a
placeholder. If the board counter is 4-bit, the HDL is already right and the
source gains a provenance note; if wider or differently clocked, the HDL
follows the trace.
