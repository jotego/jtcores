# Boot RAM test and warm reset

Namco System 1 uses the tri-port RAM as both working memory and an inter-CPU
handshake area. Two related behaviours must be kept separate:

1. a warm reset can skip the power-up test when the previous handshake survives;
2. Blast Off can fail the test itself because its sound program modifies a byte
   while the MCU is testing it.

The first behaviour is common to the games. The second is specific to the Blast
Off sound ROM.

## Shared RAM test

The main, sub, sound, and MCU CPUs share 2 KiB of tri-port RAM. It appears at a
different address in each CPU's map:

| CPU | Address range | Shared offset |
| --- | --- | --- |
| Main/sub, bank `0x17f` | `$3000-$37ff` | `$000-$7ff` |
| Sound | `$7000-$77ff` | `$000-$7ff` |
| MCU | `$c000-$c7ff` | `$000-$7ff` |

All Namco System 1 sets use the same `cus64-64a1.mcu` internal ROM, so the MCU
fill-and-verify routine is common rather than game code. The main-program boot
code is also the same around the handshake and test entry in the five ROMs
checked here: Bakutotu, Blazer, Blast Off, Dangerous Seed, and Dragon Spirit.

During the shared-RAM test the MCU writes a byte pattern and later reads it back.
The measured MCU loop time is 9.77 us per byte in the core and 9.76 us in MAME.
At shared offset `$101`, the expected byte is `$f7`; the measured interval from
that write to its verification read is 20.39 ms.

Bakutotu, Blazer, Dangerous Seed, and Dragon Spirit complete this test in the
core. Their sound programs do not modify shared offset `$101` during the test.

## Why Blast Off reports `IO ERROR 64`

Blast Off's sound IRQ handler treats the byte at sound address `$7101` as a
command mailbox. `$7101` is the same physical byte as MCU address `$c101` and
shared offset `$101`.

When the IRQ handler reads `$f7`, its `BITB #$40` test succeeds and it
acknowledges the command by writing `$80` to `$7101`. The MCU then reads `$80`
instead of the `$f7` test pattern and reports `IO ERROR 64`.

The byte is exposed for 20.39 ms, while the sound IRQ period is approximately
16.7 ms, so the collision is expected from the observed timing. The core and
MAME reproduce the same `$f7 -> $80` replacement and the same error. MAME's
driver documents the concurrent access but does not establish that a physical
Blast Off PCB passes this test. Until PCB evidence says otherwise, filtering the
sound write must be described as an optional compatibility workaround, not as
verified hardware behaviour.

## Cold and warm boot decision

After releasing the sub, sound, and MCU CPUs, the main CPU maps bank `$017f` and
runs a 16-bit timeout loop. The complete predicate is:

```text
tri_ram[$000] == $a6 && tri_ram[$00f] != $00
```

Blast Off contains this sequence:

```text
C026  LDA  #$01 / STA $F000       release the other CPUs
C02B  LDD  #$017F / STD $E200     map tri-port RAM at $3000
C031  LDA  #$A6
C033  LDX  #$0000                 16-bit timeout counter
C036  STA  $F200                  kick watchdog
C039  LEAX $1,X
C03B  BEQ  $C067                  timeout: enter power-up path
C03D  STA  $F200
C040  CMPA $3000                  shared offset $000 must be $A6
C043  BNE  $C036
C045  TST  $300F                  shared offset $00F must be nonzero
C048  BEQ  $C03D
C04A  ...                         handshake complete: skip the test
```

The first cold/warm PC-trace divergence was at `C040`, because the `$a6` compare
is evaluated first. It is not the whole decision: offset `$00f` is a second,
required condition. The loop lasts about 0.65 seconds before the counter wraps.

The five available main ROMs use the same logic:

| Game | `$a6` compare | `$00f` test | Success | Timeout |
| --- | ---: | ---: | ---: | ---: |
| Bakutotu | `$c040` | `$c045` | `$c04a` | `$c067` |
| Blast Off | `$c040` | `$c045` | `$c04a` | `$c067` |
| Dangerous Seed | `$c040` | `$c045` | `$c04a` | `$c067` |
| Blazer | `$c03d` | `$c042` | `$c047` | `$c062` |
| Dragon Spirit | `$c03d` | `$c042` | `$c047` | `$c062` |

The Blazer and Dragon Spirit block is the same code shifted three bytes earlier.
A bounded MAME run for each game also reached the listed success address after a
soft reset. The warm-start mechanism is therefore common System 1 behaviour,
not a Blast Off-specific branch.

On a cold boot the handshake pair is not accepted before the timeout, so the
main program takes the power-up path. On a MAME warm reset the previous shared
state satisfies both conditions in time and the test is skipped. MAME also has
an explicit `mcu_patch_w` workaround for offset zero: after observing `$a6`, it
prevents later MCU writes from replacing that byte. This is MAME behaviour, not
an explanation of the original circuit.

## Current core behaviour

The tri-port BRAM itself is not cleared by the board-reset pulse, but retained
RAM alone is not sufficient. In the current core the complete `$a6`/nonzero
handshake is not visible to the main CPU before its timeout after a warm reset.
The exact reset/writer ordering that destroys or delays the pair is still
unresolved; it must be measured at the main CPU's actual read-latch cycles before
assigning the fault to either byte.

As a result, every game currently takes the power-up test path again after a
warm reset:

- the other games pass the common RAM test and continue, so the missing warm
  shortcut mostly adds another diagnostic delay;
- Blast Off reaches the same test, suffers its sound-ROM `$f7 -> $80` collision,
  and stops on `IO ERROR 64`.

These are overlapping defects with different scopes. The preferred common fix
is to reproduce the warm handshake and reset ordering for all games. A separate
Blast Off-only workaround may suppress the offending sound acknowledgement when
the existing `Sound fix` DIP is enabled, but that would make the diagnostic pass
by policy and would not prove a hardware mechanism.

## Related sources

- `namcos1.cpp` contains MAME's notes about the `$a6` mystery and Blast Off's
  concurrent `$7101`/`$c101` access.
- `namcos1_m.cpp` contains MAME's `mcu_patch_w` workaround.
- `../hdl/jtshouse_triram.v` contains the current issue #410 offset-zero write
  filter.
- [jtcores issue #410](https://github.com/jotego/jtcores/issues/410) records the
  original MCU/shared-RAM handshake investigation.
