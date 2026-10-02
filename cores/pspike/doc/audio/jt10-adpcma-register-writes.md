# jt10 ADPCM-A: CPU register writes can be lost or overwritten

A CPU write to an ADPCM-A start/end address register only reaches the channel
if the channel's slot happens to pass while the write is still pending, and a
second write to that register group replaces the first one before it lands.
Fast drivers lose updates.

Found on the Video System C7-01 boards (`pspikes`, `turbofrc`, `aerofgtb`,
`karatblz`) while bringing up the `pspike` core in jtcores. `taitox` uses the
same engine and has the same exposure.

Line numbers are against jt12 `dc9be7c`.

## What the hardware does

The YM2610 has a register file the CPU writes into, and a BUSY flag telling the
CPU when the chip has taken the write. BUSY is about 24 µs; a driver that polls
it never gets ahead of the chip.

## What jt10 does

ADPCM-A start/end are not a register file. They are the six stage rotating
pipeline itself: `start1..start6`, `end1..end6`, `bank1..bank6` in
`hdl/adpcm/jt10_adpcm_cnt.v`, advanced one stage per `cen6` tick. The CPU write
is injected at a single seam, and only while that channel's own slot is passing:

```verilog
// jt10_adpcm_cnt.v:122
wire up1 = cur_ch == addr_ch_dec;
// :149
start2 <= (up_start && up1) ? addr_in[11:0] : start1;
end2   <= (up_end   && up1) ? addr_in[11:0] : end1;
bank2  <= (up_start && up1) ? addr_in[16:12] : bank1;
```

`cur_ch` is the one-hot slot counter in `hdl/adpcm/jt10_adpcm_drvA.v:90`,
clocked by `cen6`, which `jt12_top.v:198` drives at 666 kHz. Six slots at
1.5 µs, so the seam for any given channel comes round once every **9 µs**.

Meanwhile `up_start` / `up_end` are held levels, not pulses, and there is one
pair shared by all six channels:

```verilog
// jt12_mmr.v:362
{up_end, up_start} <= selected_register[5:4];
```

They are cleared only by reset or by the next write into that register group.

## The two failure modes

Both follow from the above.

**A pending write is dropped when a second one arrives first.** Write channel 0
START, then channel 1 START 6 µs later. The seam for channel 0 has not come
round yet, `up_addr` and `addr_in` are overwritten, and channel 0 never gets its
start address.

**Writing END clears a pending START.** `selected_register[5:4]` decodes to
`2'b01` for START and `2'b10` for END, and the assignment writes both bits, so
setting `up_end` clears `up_start` in the same cycle. A driver that writes START
then END back to back - the normal order - loses the START whenever the seam
falls between the two.

Neither needs an unusual driver. The pspikes sound driver does not poll BUSY
(there is nothing to poll: jt10 has no BUSY output) and writes about 6 µs apart,
under the 9 µs rotation, so it hits both.

This is ADPCM-A only. ADPCM-B is a single channel with no rotation, and its
registers are on the other side of the part select
(`jt12_mmr.v:273` `part <= addr[1]`, ADPCM-A at `:344`, ADPCM-B at `:374`).

## The workaround in jtcores, and why it is in the wrong place

`cores/pspike/hdl/jtpspike_snd.v` holds the Z80 for one full rotation after
every write to the ADPCM-A bank, so the seam is always reached before the next
write:

```verilog
assign fm_wr   = fm_cs & ~wr_n;
assign fm_busy = busy_cnt!=0;

always @(posedge clk) begin
    if( rst ) begin
        busy_cnt <= 0;
        fmwr_l   <= 0;
    end else begin
        fmwr_l <= fm_wr;
        if( fmwr_l && !fm_wr && A[1:0]==2'b11 )   // end of a bank-1 data write
            busy_cnt <= 7'd96;                     // 12us at 8MHz
        else if( fm_cen && busy_cnt!=0 )
            busy_cnt <= busy_cnt-7'd1;
    end
end
```

It works, but it is a core synthesising a BUSY the chip should be providing, and
it has three problems:

- It fires on every bank-1 data write, including key-on and TL, which do not
  need it.
- A driver that legitimately polls BUSY would work on real hardware and stall
  here, because there is still no BUSY to poll.
- Every other core using jt10's ADPCM-A carries the bug with no workaround.
  `cores/taitox/hdl/jttaitox_sup_snd.v:120` instantiates `jt10b` with a plain
  `.cen(cen8)`, no hold - it is exposed, its driver's write pattern just does
  not happen to trigger it.

Worth noting both cores gate the chip cen on the ADPCM ROM wait
(`gate: [pcma, pcmb] -> fm_cen` in `cores/pspike/cfg/mem.yaml`, the same for
`adpcma`/`adpcmb` in taitox), so under SDRAM stalls a rotation takes longer than
the nominal 9 µs and the window is wider than on the real chip.

## Possible fixes, in jt12

**Per-channel pending write.** Replace the single `{up_end, up_start, up_addr,
addr_in}` with one pending latch per channel, cleared when its seam consumes it.
Removes both failure modes, no interface change, and the core-side hold can go.

**Real start/end registers.** Take start/end/bank out of the shift chain into a
six entry register file the pipeline reads. Closer to the real chip, a larger
change.

**Expose BUSY.** Useful on its own - drivers that poll it currently cannot -
but it does not fix anything by itself, since the affected drivers do not poll.

## Reproducing

`cores/pspike` in jtcores, `pspikes` romset. Remove the `busy_cnt` block from
`jtpspike_snd.v` and the percussion drops out or plays from the wrong offsets.
The sound driver's write pattern is visible in `doc/audio/`.
