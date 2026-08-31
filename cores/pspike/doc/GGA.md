# Video System C7-01 GGA

Video timing gate array. Write-only through an address/data pair: the odd byte
latches a 4-bit register index, the even byte writes that register. 16 registers,
of which 12 are ever written by any game.

MAME models it as a skeleton device (`vsystem_gga.cpp`) that only stores the
register file, so the meanings below are reverse engineered from the register
values of 50 machines cross-referenced against each driver's `set_visarea`. Only
two facts come from MAME itself:

- `fromance_v.cpp` computes `visarea.max_x = ((m_gga->reg(0)+1)*4) - 1`, which is
  the horizontal formula below.
- the same file marks the vertical geometry `TODO: guesswork` and hardcodes
  `max_y = 240 - 1`, so no driver's vertical visarea is authoritative.

## Registers

| reg | name | meaning |
|---|---|---|
| 00 | `hbend` | last visible pixel, `(r+1)*4 - 1`. Width is `(r+1)*4` |
| 01 | `hsst` | HS rise, `(r+1)*4` |
| 02 | `hsend` | HS fall, `(r+1)*4` |
| 03 | `htot` | last H count, `(r+1)*4 - 1`. Total is `(r+1)*4` |
| 04 | ? | not geometry. `1f` usually, `18` on ccasino, `ff` on spinlbrk/rpunch |
| 05 | ? | not geometry. `0`, `1`, `4` or `9` |
| 06 | - | never written |
| 07 | - | never written |
| 08 | `vbend` | last visible line, `(r+1)*2 - 1`. Height is `(r+1)*2` |
| 09 | `vsst` | VS rise, `(r+1)*2` |
| 0a | `vsend` | VS fall, `(r+1)*2` |
| 0b | `vtot` + IRQ | last V count, `(r+1)*2 - 1`, and the interrupt rate select |
| 0c | ? | not geometry. `1f` usually, `ff` on spinlbrk |
| 0d | ? | not geometry. `0` or `2` |
| 0e | - | never written |
| 0f | - | never written |

`04`/`05` and `0c`/`0d` form a per-axis pair. Neither correlates with any
visible area, and the chip is known to generate an interrupt, so they are more
likely an interrupt position (an H and a V coordinate) than display geometry.

`0d` is specifically **not** a vertical display start. `0d=2` occurs with three
different MAME Y origins - svolley (0), aerofgtb (4), f1gp (8) - and `0d=0`
occurs on games that lose lines (welltris, pipedrm, hatris). Uncorrelated in
both directions.

## Register values per game

Captured from MAME by tapping the CPU write port. `06/07/0e/0f` omitted, they
are never written.

| games | 00 | 01 | 02 | 03 | 04 | 05 | 08 | 09 | 0a | 0b | 0c | 0d | WxH | shown |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| pspikes x3, turbofrc x4, karatblz x5, svolly91 | 57 | 63 | 69 | 71 | 1f | 0 | 77 | 79 | 7b | 7f | 1f | 0 | 352x240 | 240 |
| spinlbrk x3 | 57 | 68 | 6f | 75 | ff | 1 | 77 | 78 | 7b | 7f | ff | 0 | 352x240 | 240 |
| spinlbrkup | 57 | 68 | 6f | 71 | ff | 1 | 77 | 78 | 7b | 7f | ff | 0 | 352x240 | 240 |
| aerofgtb, aerofgtc, sonicwi | 4f | 5d | 63 | 71 | 1f | 0 | 6f | 70 | 72 | 7c | 1f | 2 | 320x224 | 224 |
| quiz18k | 4f | 5d | 63 | 70 | 1f | 0 | 6f | 70 | 72 | 7c | 1f | 0 | 320x224 | 224 |
| ojankohs | 47 | 55 | 5d | 6b | 1f | 4 | 6f | 73 | 77 | 7f | 1f | 0 | 288x224 | 224 |
| ccasino | 47 | 55 | 5d | 6b | 18 | 4 | 6f | 73 | 77 | 7f | 1f | 0 | 288x224 | 224 |
| rpunch | 47 | 57 | 61 | 6b | 00 | 1 | 6b | 73 | 77 | 00 | 1f | 0 | 288x216 | 216 |
| rabiolep | 47 | 57 | 61 | 6b | 00 | 1 | 6b | 73 | 77 | 7f | 1f | 0 | 288x216 | 216 |
| svolley | 47 | 57 | 61 | 6b | 1f | 1 | 6b | 73 | 77 | 7f | 1f | 2 | 288x216 | 216 |
| svolleyk | 47 | 57 | 61 | 6b | 1f | 1 | 6b | 73 | 77 | 7f | 1f | 0 | 288x216 | 216 |
| nekkyoku | 4f | 62 | 69 | 71 | 1f | 4 | 79 | 7a | 7d | 7f | 1f | 0 | 320x244 | - |
| f1gp x3, sformula x2, tail2nos x2 | 4f | 5e | 64 | 71 | 1f | 9 | 7a | 7c | 7e | 7f | 1f | 2 | 320x246 | 240 |
| welltris x2, pipedrm x4, hatris x3 | 57 | 63 | 69 | 71 | 1f | 0 | 7a | 7b | 7e | 7f | 1f | 0 | 352x246 | 240 |
| fromance, daiyogen, idolmj, mjnatsu, natsuiro, nmsengen, mfunclub | 57 | 63 | 69 | 71 | 1f | 0 | 7a | 7b | 7e | 7f | 1f | 0 | 352x246 | 240 |

`WxH` is what the registers decode to. `shown` is what MAME displays and what
original hardware footage shows.

## reg 08 = 7a loses six lines

Every value of `08` except `7a` is displayed in full: `6b` gives 216, `6f` gives
224, `77` gives 240, `79` gives 244, all matching their driver's visarea exactly.
`7a` decodes to 246 but only 240 reach the screen, and it does so across four
drivers, two widths and nineteen machines. The cut is tied to the `7a` setting
itself and not to any other register - `05`/`0d` are `9`/`2` on f1gp but `0`/`0`
on welltris, pipedrm, hatris and the fromance family, which lose the same six
lines.

The six lines are cut, not blanked: original hardware footage is centred with no
extra dead lines at either edge. Whether the true height is 240 or 238 cannot be
told from footage.

## reg 0b also selects the interrupt rate

`rpunch` and `fromance` are the only drivers that install a `write_cb` and act on
a register. Both use `0b` to schedule the CRTC interrupt:

```c
// rpunch
case 0x0b: m_crtc_timer->adjust(m_screen->time_until_vblank_start(), (data == 0xc0) ? 2 : 1);
// fromance
case 0x0b: m_crtc_timer->adjust(m_screen->time_until_vblank_start(), (data >  0x80) ? 2 : 1);
```

The callback raises IRQ1 and re-arms itself at `frame_period / param`, so `param`
is interrupts per frame: 1 means one IRQ at vblank, 2 means a second one at
mid-frame. The high bits of `0b` are therefore a flag, not part of the vertical
total. Note the two drivers test it differently (`== 0xc0` versus `> 0x80`) for
the same chip, so this is MAME's inference rather than documentation.

## Games that do not just set and forget

**ccasino** rewrites `0b` at runtime as `ff -> bf -> 7f`. Under the rule above the
first two select two interrupts per frame and the last drops back to one, so the
game switches interrupt rate between screens. A decoder that feeds all eight bits
of `0b` into the vertical total would compute 512 lines for `ff`.

**nekkyoku** is the only game that reprograms the vertical timing per screen.
MAME's `fromance_v.cpp` records `79 7a 7d 7f` for the gameplay and title screens
and `77 79 7d 7e` for the gals display, i.e. 244 lines against 240, with the sync
edges moving with it.

**rpunch** writes `0b` as `00` during boot before settling; `rabiolep`, the same
game on the same hardware, shows `7f`. Capturing a register file mid-sequence can
catch these intermediate values.

**spinlbrkup** programs `03` as `71` where the other spinlbrk sets use `75`, a
genuine per-set difference in horizontal total (456 against 472).

**fromance, pipedrm, rpunch and their clones** consume GGA writes through
`write_cb`, so they never reach the device's `logerror`. Capturing them needs a
tap on the CPU port: `fromance`/`pipedrm`/`ojankohs` map the GGA to Z80 I/O ports
`0x10-0x11` (on the CPU tagged `sub` for fromance), while `rpunch` uses
`map(0x0c0009, 0x0c0009).select(0x20)` with `m_gga->write(offset >> 5, data)`, so
data is at `0c0009` and the address latch at `0c0029`.
