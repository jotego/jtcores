# Field-to-word adapter

`jttms10_field` accepts one right-justified 1–32-bit field at a 32-bit bit
address. It reads or writes one to three aligned, ascending 16-bit words.
Read data is zero-extended in `rdata`. A fully covered word is written
directly; a partial word is read, merged, and written to preserve bits outside
the field. `ack` remains high until the architectural `req` goes low. The
caller must hold `req` and its payload through `ack` and lower `req` before
starting another field.

`word_ack` is a one-clock pulse for each accepted physical word request.
`word_req`, `word_we`, `word_addr`, and `word_wdata` remain stable while that
word waits for its acknowledgement. After an acknowledgement, `word_req` may
stay high while the adapter changes the payload to the next word or from a
partial-word read to its matching write. The word-bus controller must treat
the acknowledgement edge as the boundary between requests, even if
`word_req` never falls. `word_lock` stays high from the partial-word read
request through its matching write acknowledgement; arbitration must keep
that pair together. This interface has no restart input for a lock broken by
HOLD.

To limit combinational shift logic, the adapter shifts a 48-bit data/mask
window left once per bit offset before bus access and shifts the captured
read window right once per bit offset afterward. Each direction adds 0–15
clocks. Writes also use one selection clock per physical word; partial words
need two word-bus acknowledgements. Read completion uses one further clock
to copy the aligned result. These clocks are in addition to word-bus waits.

Simulation covers every offset 0–15 and size 1–32, with waits, whole-memory
write-preservation checks, lock pairing, and reset during a read. NARC
performance and silicon timing are unverified. The serial alignment latency
may exceed the TMS34010 timing budget; measure it in the integrated NARC
workload and optimize before replacing the existing core.
