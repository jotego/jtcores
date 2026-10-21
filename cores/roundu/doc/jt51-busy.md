# jt51 busy flag misses short write strobes

Round Up 5 usually boots into `HARDWARE BAD 33  OPM BUSY IS HOLD 0` and the
hardware-test IO TEST flickers between pass and fail. The message decodes as
"busy stuck at 0": the game's Z80 verdict routine (audio ROM, `0x29ed`)
requires BUSY high on the first status read after a data write, about 2.2 us
later, and low again within ~325 us:

```
29f2: ld (hl),$10      ; address register, HL=FFF0
      5 x nop
29fa: ld (hl),$FF      ; data register, HL=FFF1  -> busy must rise
29fc: bit 7,(hl)       ; ~2.2 us after the write strobe
29fe: jr z, BAD33_HOLD0 ; busy low here = "OPM BUSY IS HOLD 0"
2a00: ld b,$64
2a02: djnz $            ; ~325 us
2a04: bit 7,(hl)
2a06: jr nz,BAD33_HOLD1 ; busy still high = "OPM BUSY IS HOLD 1"
```

In jt51, register writes capture at clock rate, but busy only sets when a
`cen` (P1, half the chip rate) edge samples the strobe (`hdl/jt51_mmr.v`):

```verilog
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        busy_cnt <= 0;
        busy     <= 0;
    end else if(cen) begin
        busy <= write&a0 | (busy & ~nx_busy[5]);
        busy_cnt <= nx_busy[4:0];
    end
end
```

A write strobe shorter than one P1 period can update the register while busy
never rises. A phase sweep (50 offsets, fractional 4 MHz cen from 50.3 MHz,
`cores/roundu/ver/roundup5/scratch/iotest/busy_tb.v`):

| strobe width | busy missed |
| --- | --- |
| 12 clk (~1 Z80 T-state) | 20 / 50 |
| 25 clk (~2 T-states) | 0 / 50, busy length 15.5-15.9 us |

SDRAM wait states shift the Z80's phase against the FM cen chain on every
boot, which makes the failure intermittent and retry-sensitive.

Proposed change (tested, 0 misses / 100 across both widths; release timing
unchanged): raise busy with the write itself, keep the P1 countdown for the
release, as the real chip raises busy on the write strobe.

```verilog
end else if( write&a0 ) begin
    busy     <= 1;
    busy_cnt <= 0;
end else if(cen) begin
    busy <= busy & ~nx_busy[5];
    busy_cnt <= nx_busy[4:0];
end
```

Notes:

- The boot-time soft flag at Z80 `$FF82` (a tighter 2-read loop) is set to
  `FF` even in MAME 0.282 (Lua memory dump) and is not fatal; only the
  verdict routine above decides HARDWARE GOOD/BAD.
- Possibly related to the rastan sound-test investigation (jtcores#1215 and
  the jt51 `rastan-busy128` experiment branch): that experiment lengthened
  busy, while this failure mode is about the assertion edge, not the length.
- Experiment commit with the change: local jt51 branch `roundup5-busy-set`
  (3d22e53), currently not pushed; the submodule stays on the upstream pin.
