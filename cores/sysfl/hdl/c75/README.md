# jt37702 — Mitsubishi M37702 MCU (Namco C75)

Synthesizable, cen-driven M37702 for the Namco System FL core: the sound/IO
CPU (C75 custom = M37702 + 16kB internal mask ROM, dumped as `c75.bin` in the
MAME `namcoc75` device set). The behavioral reference is MAME's
`src/devices/cpu/m37710/` (m37710.cpp + m37710op.h opcode tables): instruction
semantics, flag details, interrupt priority scheme and the on-chip register
file all mirror MAME, including its quirks (PUL bit 6 ignored, DIV setting
C=V, MVN/MVP rewinding PC by 3 to stay interruptible).

## Files

| file             | content                                                  |
|------------------|----------------------------------------------------------|
| `jt37702.sv`     | top: bus unit (internal/external routing, byte/word split), 512B internal RAM |
| `jt37702_cpu.sv` | execution engine: decode tables, EA sequencer, ALU, stack engine, divider, interrupt entry |
| `jt37702_per.sv` | ports 0-8, timers A0-A4/B0-B2, 8-bit ADC, interrupt controller, UART/watchdog stubs |

`jtframe_edge` (jtframe_edge_pulse) latches the INT0-2 pins and timer event
inputs.

## Architecture (7700 series vs 65C816)

Same base model as the 65C816: A, X, Y, S, DPR, 16-bit PC + 8-bit program
bank (PG), 8-bit data bank (DT), m/x width flags via SEP/CLP (CLP replaces
REP). 7700 deltas, all taken from the MAME execution tables — the 7700
datasheet opcode map matches them:

- Second 16-bit accumulator B. Prefix `42h` turns any A-accumulator opcode
  into its B version (plus TAS/TSA/TAD/TDA, PHA/PLA, INC/DEC A, shifts).
- Prefix `89h` adds MPY, DIV (32/16 or 16/8), RLA #n, XAB, LDT #imm.
- No emulation mode, no XCE, no NMI pin. IPL 3-bit priority level, pushed
  and popped as an extra byte with PS (PHP/PLP/interrupts push both).
- SEB/CLB (set/clear memory bits), BBS/BBC (branch on bits, operand order
  `op dd #imm rel`), LDM (immediate to memory) replace TSB/TRB/STZ/BIT.
- INC A/DEC A swapped: `1Ah`=DEC A, `3Ah`=INC A. `D8h`=CLM, `F8h`=SEM.
- WIT (`CBh`) and STP (`DBh`). BRK vectors at FFFA, divide-by-zero at FFFC.
- High bytes of A/B/X/Y are preserved through 8-bit mode (kept naturally by
  full-width registers with byte-lane writes).
- All registers boot in 16-bit mode (m=x=0), S=0100h, I=1, PC=(FFFE).

## ISA coverage

| group | status |
|-------|--------|
| ALU (ORA/AND/EOR/ADC/SBC/CMP/LDA + B versions) all 15 modes | done |
| LDX/LDY/STX/STY/CPX/CPY, STA/STB | done |
| memory RMW (ASL/ROL/LSR/ROR/INC/DEC d/dx/a/ax) + acc versions | done |
| SEB/CLB/LDM/BBS/BBC (d and a forms, m-width immediates) | done |
| branches, BRL, JMP a/al/(a)/(a,x), JML, JSR/JSL/RTS/RTL/RTI | done |
| INX/INY/DEX/DEY (missed by the first pass, C75 BIOS uses them at reset) | done |
| stack: PH?/PL? singles, PEA/PEI/PER, PSH/PUL register lists | done |
| MVN/MVP (byte-wise, PC rewind, ends with A=FFFF, DT=dest) | done |
| MPY (combinational), DIV (32-cycle restoring, /0 traps to FFFC) | done |
| RLA, XAB, LDT, SEP/CLP, transfers, WIT, STP, BRK | done |
| decimal mode (D flag) | **TODO**: flag stored, ADC/SBC stay binary |
| 7750-only opcodes (MPYS/DIVS/EXTS/EXTZ, 89 28x-2Bx block) | not on 37702, decoded as NOP+warning |
| unimplemented table entries | NOP + `$display` in simulation |

Cycle counts are approximate: every bus byte/word costs ~3 cen (see bus
below), sequencer states 1 cen. MAME charges ~1-2 XIN clocks per access, so
run `cen` at 2-3x the original 16.128MHz XIN for equivalent throughput, or
accept a slower sound driver (self-timed against its own timers, so usually
harmless).

## Peripherals (M37702M2 register file, 00h-7Fh)

| block | status |
|-------|--------|
| ports P0-P8 data+direction regs (datasheet interleaved layout) | done; P4-P8 pinned out, P0-P3 internal-only |
| timers A0-A4, B0-B2: timer mode (f2 /2/16/64/512 prescale, reload, IRQ) | done |
| timer A event-counter mode (tain pins, up_down reg, reload+IRQ on wrap) | done (MAME never wraps; hardware does — namcofl uses this per driver notes) |
| timer one-shot / PWM / pulse measurement modes | TODO (regs stored) |
| ADC: single, repeat and sweep conversions, 8-bit results, 228/456-cen timing, IRQ on stop | done |
| interrupt controller: 16 sources (ADC, UARTs, timers, INT0-2), 3-bit priorities, request bit 3, ties resolved to the higher index like MAME | done |
| INT0/INT1/INT2 pins | rising-edge only (namcofl uses HOLD_LINE pulses); level-sense bit ignored, as in MAME |
| UART0/1 | register stubs, no serial engine |
| watchdog | stub: 60h write ignored, 61h freq reg stored |
| DMA controller (37720 only) | not present on 37702 |

One deliberate divergence from MAME: writing bit 3 of an interrupt control
register raises/clears that request like real silicon; MAME keeps a separate
line state and ignores software writes to bit 3.

## Memory map / bus

Internal (bank 0 only): `00-7F` peripheral registers (byte-wide, word access
split), `80-27F` 512B RAM (single-cen when aligned), `C000-FFFF` internal ROM
through `rom_cs/rom_addr[13:1]/rom_data/rom_ok` so mem.yaml owns the storage.
Aligned internal-ROM fetches are self-timed at 2 cen (the BRAM is addressed
one cen early and assumed to have 1-clk latency); `rom_ok` only gates the
split (misaligned 16-bit) accesses.
Everything else drives the external bus — on System FL: `2000-2FFF` C352,
`4000-BFFF` shared RAM, `200000-27FFFF` external data ROM.

jtframe DTACK style, all state advances on `cen`, transactions complete on
`cen & bus_ok`:

```
          ___     ___     ___     ___     ___
cen    __|   |___|   |___|   |___|   |___|
bus_cs ______/^^^^^^^^^^^^^^^^^^^^^\_________
addr   ------< stable                >-------
bus_ok _________________/^^^^^^^^^^^\________
```

`dsn[1:0]` are active-low byte lanes (0=even byte on din/dout[7:0]). Aligned
16-bit transfers use one cycle (`dsn=00`); misaligned ones become two byte
cycles automatically. `an[63:0]` packs an0 (bits 7:0) to an7. On namcofl:
p6 in/out (C352 bank + comms), p7 in (input mux), an5=wheel, an6=brake DAC,
an7=accel, IRQ0/IRQ2 ticked at 60Hz by the board.

## Where c75.bin lives

MAME loads the internal ROM from the `namcoc75` device set (`c75.bin`, 16384
bytes, CRC 42f539a5), not from the game zips — `speedrcr.7z` only carries the
game program/data. Locally: `~/develop/mame/roms/namcoc75.zip`.

## TODO, in priority order

1. Decimal mode ADC/SBC (BCD adjust per MAME's digit-wise algorithm) — only
   needed if the C75 BIOS uses it (sound drivers usually do not).
2. Cycle-count tightening: single-cen internal ROM/register access, opcode
   prefetch. Only matters for CPU-bound comms windows with the i960.
3. Timer one-shot and PWM modes; timer B pulse measurement.
4. Verify against the real BIOS: run `c75.bin` + `speedrcr` data ROM in the
   game harness and compare the shared-RAM protocol against MAME traces.
5. UART engine if any System FL title turns out to use it (none known).
6. WIT wake-up on masked interrupts (MAME only wakes on dispatched ones;
   real hardware also resumes on masked requests — check with the BIOS).

## Smoke test

`ver/c75/go.sh` (iverilog, docker image `jotego/simulator:arm64`) runs a
hand-assembled program from the internal ROM image with random external-bus
wait states: reset vector, 16/8-bit mode switches with high-byte
preservation, absolute/indexed/direct/indirect/misaligned accesses, MVN,
LDM/SEB/CLB/BBS, MPY/DIV/XAB, PSH/PUL, JSR/RTS, a port 6 write, a port 7
read, an ADC conversion, a timer A0 interrupt and an external INT0 through
the vector table. Prints PASS/FAIL; `vvp ... +trace` gives an instruction
trace.

## System FL boot status (speedrcr)

The real BIOS boots end-to-end in RTL and drives the i960 to the attract
sequence: POST -> SELFTEST END -> Namco/Pac-Man logo (frame ~66 fastboot,
matching MAME's ~16s cold splash). The i960<->C75 handshake self-paces; no
artificial delay is needed once an instruction cache is present on jt960 and
a warm NVRAM image is supplied (a fresh 0xFF NVRAM still has one open
divergence in the wheel-calibration default copy - see boot notes).

C352: the BIOS initializes it (ctrl 0x0e0f, per-voice flag clears) and the
i960 fills a sound-command block in shared RAM. First actual voice keyon in
MAME is ~frame 57 of the warm boot, well past the logo; the FPGA reaches the
logo but the attract audio window is beyond current sim depth, so the sound
capture is still silent (on-timeline, not a fault). No jt352 divergence seen.

Fixed jt37702 divergences this pass: DEX/DEY/INX/INY (0xCA/0x88/0xE8/0xC8)
were missing and the BIOS hits DEX in its first RAM-clear loop; added a
self-timed 2-cen internal-ROM fetch path. Throughput note: bring-up runs the
MCU cen at full rate, timers and ADC on tcen = xin_cen (clk/3); lower cen after the cycle-tightening.
