# Handoff: shouse / blastoff warm-boot divergence from MAME

## What you are being asked to solve

On a **warm reset** (board reset without power cycle), MAME's blastoff **skips** the power-up
self-test and goes to the service menu. Our core **re-runs the test every time** and lands on the
error screen. Reproduced in sim and on MiSTer hardware.

This is a *separate* problem from the self-test failing (see "Not your problem" below). Fixing this
would give a working path into the service menu; it will not make the test pass.

## The decision point (established, read from the ROM)

Disassembled at a live breakpoint, so the banks were correct:

```
C026: LDA  #$01 / STA $F000     ; release SUBRES (sub, sound, MCU start)
C02B: LDD  #$017F / STD $E200   ; page 1 -> bank 017F, so $3000 = tri-RAM offset 0
C031: LDA  #$A6
C033: LDX  #$0000               ; timeout counter
C036: STA  $F200                ; kick watchdog
C039: LEAX $1,X
C03B: BEQ  $C067                ; counter wrapped -> GIVE UP -> self-test path
C03D: STA  $F200
C040: CMPA $3000                ; <<< THE SWITCH: is tri-RAM[0] == 0xA6 ?
C043: BNE  $C036                ; no -> keep waiting
C045: TST  $300F                ; tri-RAM[0x0F]
C048: BEQ  $C03D                ; zero -> keep waiting
C04A: ...                       ; both satisfied -> normal boot, NO test
```

It is a **timeout race**, roughly 0.65 s (16-bit counter, ~10 us/iteration). Not a
"is memory blank" check. MAME wins the race on a warm boot because `A6` is already sitting in
tri-RAM offset 0 from the previous run.

Bank arithmetic: the C117 maps `bank * 0x2000`, and `jtc117.v` decodes on `address[22:12]`, which
agrees with MAME's `virtual_map`. Bank `0x17F` = `0x2FE000-0x2FFFFF`: CUS30 in the low 4K,
tri-port RAM in the high 4K. So `$3000` with `E200=017F` is tri-RAM offset 0.

## How the switch was found (repeat this if you distrust it)

Diff the main CPU's PC stream, cold vs warm, over the same window.

```
trace off
focus 0
gtime #400
trace /tmp/div_cold.tr,maincpu,noloop,{tracelog "%X\n",pc}
gtime #3300
traceflush
trace off
gtime #8000
softreset
gtime #400
trace /tmp/div_warm.tr,maincpu,noloop,{tracelog "%X\n",pc}
gtime #3300
traceflush
quit
```

Strip the disassembly lines, align the two streams (the warm one starts with an extra `FF80`
reset-vector fetch, and both begin mid-loop so you need a small shift search), then walk to the
first mismatch. Result: **identical for 128,443 instructions**, then

```
cold: ... C036 C039 C03B C03D C040 C043  C036 ...   (keeps looping)
warm: ... C036 C039 C03B C03D C040 C043  C045 ...   (breaks out)
```

## The A6 machinery and our hacks

**MAME** (`namcos1.cpp` notes + `c117.cpp`): the MCU writes `A6` to `$C000` (tri-RAM offset 0)
once at init, then repeatedly copies the low nibble of `$C02F` there. MAME's `mcu_patch_w`
**ignores the MCU's zeroing writes** so `A6` survives.

**jtcores issue #410** covers this: the MCU can never regenerate `A6` (only the low nibble of
`$C02F` is parsed); the main CPUs post `0E` then `08` at `$302F`; the reported lockup was the MCU
never reaching the routine that clears `$C02F`; the diagnosis pointed at the mapper's reset signal
to sub/MCU/sound. Read it: https://github.com/jotego/jtcores/issues/410

**Our HDL hack** — `cores/shouse/hdl/jtshouse_triram.v`:

```verilog
.we1( xwe && (xaddr != 0 || xdout == 8'ha6 || xsel) )   // issue #410
```

Port 1 is time-shared between the MCU (`xsel=0`) and the sound CPU (`xsel=1`) via `snd_sel`.
The `|| xsel` term was added deliberately in PR #656 (Gyorgy Szombathelyi, May 2024,
commit `1d7337b28`, "Sound CPU is allowed to write anything").

Measured in MAME over a full boot, for reference:

```
sound CPU writes to tri-RAM offset 0 :      0     (and 0 anywhere in 0x00-0x0F)
MCU writes to offset 0               : 23,269    (only 2 of them A6)
main/sub writes to offset 0          :     39
```

So the exemption licenses something MAME's sound CPU never does. **But removing `|| xsel` changed
nothing** — same two errors, identical frame pattern. Do not spend time re-testing that.

## What is measured vs what is guesswork

Measured and trustworthy:
- the `C040` switch and the 128,443-instruction alignment above
- MAME warm boot lands at `C412`, cold boot at `D343` (the error halt loop), 11 s after reset
- MAME cold boot has tri-RAM[0] = `A6` as early as 100 ms
- the MAME write counts in the table above
- removing `|| xsel` has no effect

Wrong turns already taken; do not repeat them:
- **`C699` / `C6CF` / `C718` (`LDA ,X` / `LBNE`) are NOT the gate.** They skip individual region
  tests, and on a warm boot the CPU never reaches them at all (breakpoints there are never hit,
  which will hang an open-ended `go`).
- MMR register files clearing on reset is not the cause — the guards read `jtframe_dual_ram`
  blocks, and CUS30 reads come from `u_wave`, not the MMR (`read_only`, no `dout`).
- The MCU clock is correct. Measured 9.77 us per fill-loop byte against MAME's 9.76;
  `cen_mcu = |cpu_cen[3:0]` at 6.144 MHz is right because `jtframe_6801mcu` consumes four `cen`
  per machine cycle. Dividing it by 4 makes us 4x slower than the real chip.

Untrusted instrumentation — rebuild rather than reuse:
- My tri-RAM write probe labelled writes by `xsel` and computed a `blocked` flag from the same
  expression as `we1`, yet reported 285 writes tagged `mcu` with data `00` at address 0 as
  *allowed*, which that condition says is impossible. Either the label or the flag is lying.
  Log `xsel`, `xwe`, the raw `we1` condition and the port signals as **explicit fields**.
- There is no read-side probe on offset 0 at the moment `C040` samples it. That value is what
  actually decides, and nobody has measured it.

## Genuine gaps found on the way (unproven as causes)

- **No sound-CPU watchdog.** MAME's C117 needs three kickers (`ALL_CPU_MASK = 7`); the sound CPU
  kicks at `$D001` via `sound_watchdog_w`. Our `jtc117.v` has `wdogn = mwdn & swdn` (two), and
  `jtshouse_sound.v` collapses all of `C000-FFFF` into one `reg_cs` on writes, so `$D001` goes
  nowhere. This sits on the exact signal path #410 blamed. Note our watchdog is *easier* to
  satisfy, so naively it should reset less often, not more.
- `jtc117.v` gates the reset update: `if( sub_Q ) srst_n <= prstn;`, and one line drives sub,
  sound and MCU together.

## Environment

- MAME 0.276 at `~/mame/mame`, roms at `~/mameroms` (`~/.mame/roms` is a dead symlink).
- Service Mode forced at power-up via `~/mame/cfg/blastoff.cfg`:
  `<input><port tag=":DIPSW" type="DIPSWITCH" mask="1" defvalue="1" value="0" /></input>`
  Original backed up at the session scratchpad as `blastoff.cfg.bak`.
- Sim: `FRAMES=1700 ROMS_HOST=~/mameroms ./sim-core.sh shouse blastoff -dipsw fffe ../blastoff/warmreset.cab`
  `fffe` clears SW1 (service mode). `ver/blastoff/warmreset.cab` does cold boot -> reset -> warm boot.
- Verdict is mechanical: the frame dumper only writes a PNG when the image changes. A failing boot
  emits frames `681..709` then stops; a healthy one keeps emitting (bakutotu reaches 1436).
  Two identical bursts (`681..709` and `1450..1478`, same deltas) = both boots errored.

## Traps that cost time here

- **Never `pkill -f mame`** — the Docker sim's command line contains `/root/.mame/roms`, so it
  kills the Verilator run too. Kill by PID.
- A `dump` as the **first** debugger command hangs MAME. Put a short `gtime` ahead of it.
- Open-ended `go` on a breakpoint that is never reached runs forever (cost 1919 s of emulated time
  once). Prefer bounded `gtime`.
- Tracing runs at ~23% speed; a per-instruction trace of the 6.144 MHz MCU is impractically slow.
  Trace the main CPU, PC only.
- Verilator forks a child per PNG, so interleaved `$display` lines get corrupted. Dedupe and
  regex-extract; do not trust raw line order in bulk.
- Sampling `bdin` at a chip-select edge gives **stale** data — the BRAM needs a cycle, and on the
  CUS30 the bus only owns the port ~10 cycles in. Sample where the CPU latches.

## Not your problem (context only)

The self-test *failing* is a different, blastoff-specific defect: the MCU's RAM-test ramp puts `F7`
on tri-RAM `0x101`, which is blastoff's sound-CPU command mailbox; the sound IRQ handler acks
anything with bit 6 set (`D08B: BITB #$40`) by writing `80`, and the MCU's verify 20.4 ms later
reads `80` instead of `F7` -> `IO ERROR 64` at `C101`. Our core reproduces MAME bit for bit here
(9.77 us/byte, 20.39 ms window, same frame). The four other games with ROMs available (bakutotu,
blazer, dangseed, dspirit) pass because their sound CPUs never touch `0x101`.

No evidence exists that a real PCB passes this test. MAME's `namcos1.cpp:226` asserts concurrency
as the cause but never claims hardware passes, and a 20.4 ms exposure window against a ~16.7 ms
sound IRQ period says a real board would collide too. Worth settling before treating it as a bug.
