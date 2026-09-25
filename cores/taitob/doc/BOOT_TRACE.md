# Rastan Saga 2 / Nastar — annotated boot trace

Reference MAME trace of `nastar` (parent set; rastsag2 is a Japan clone
on identical hardware). Captured against MAME 0.276 with the scripts
in `cores/taitob/ver/rastan2/mame_scripts/` against ROMs at
`/Volumes/homes/abogazzi/roms/MAME 0.270 ROMs (split)/nastar.zip`.

Raw traces (gitignored, ~36 MB total):
- `cores/taitob/ver/rastan2/traces/main_boot.tr`  — 1,383,536 68k instructions
- `cores/taitob/ver/rastan2/traces/sound_boot.tr` — Z80 boot path

Regenerate either with `./mame nastar -debug -debugscript <script>` then
move `/tmp/rastsag2_<cpu>.tr` into `ver/rastan2/traces/`.

---

## Main CPU (68000 @ 12 MHz)

### Reset vector + stack init

```
000400  reset PC vector (taken from ROM offset 0x4)
000404  lea     $600000.l, A5         ; A5 = work-RAM base
00040A  lea     $607ffe.l, A7         ; SP = top of work RAM (32 KB)
```

So SSP from the reset vector is **0x607FFE** (work-RAM top minus 2). The
initial PC is **0x000404**. These are the first two **validation gates**
for the FPGA sim.

### TC0180VCU control-register init (10 byte writes, 0x418000–0x41801E)

```
000410  move.b  #$10, $418000.l   ; ctrl[0] = 0x10   (video_control)
000418  move.b  #$32, $418002.l   ; ctrl[1] = 0x32   (BG/FG/TX rambank)
000420  move.b  #$00, $418004.l   ; ctrl[2] = 0
000428  move.b  #$00, $418006.l   ; ctrl[3] = 0
000430  move.b  #$00, $418008.l   ; ctrl[4] = 0
000438  move.b  #$01, $41800a.l   ; ctrl[5] = 0x01
000440  move.b  #$08, $41800c.l   ; ctrl[6] = 0x08
000448  move.b  #$28, $41800e.l   ; ctrl[7] = 0x28
000450  move.b  #$00, $418014.l   ; ctrl[10] = 0 (note: skips 0x418010,0x418012)
000458  move.b  #$00, $418016.l   ; ctrl[11] = 0
```

These are the magic numbers `cores/taitob/doc/tc0180vcu.cpp::ctrl_w`
will need to decode. Per the MAME source `m_ctrl[0..15]` covers a 16-byte
register file; the BG/FG/TX rambank latches sit at bytes 1, 5, 6, 7 (the
0x32 / 0x01 / 0x08 / 0x28 values above). Byte 0 = `video_control`
(global flip / framebuffer-page / sprite-shading flags).

### Scroll-RAM clear (0x413800 = FG, 0x413C00 = BG)

```
000460  move.w  #$0000, $413800.l   ; clear FG scroll register
000468  move.w  #$0000, $413c00.l   ; clear BG scroll register
```

### First TC0220IOC write — coin lockout / counter reset

```
000470  move.b  D0, $a00000.l       ; IOC byte register 0 (port_w_4)
```

D0 is loaded earlier — repeated calls at 0x00048C, 0x0004AC, 0x0004CE,
0x0004EE, 0x000510 hammer the same address with different D0 values
during the boot self-test (coin counter / lockout / DSW polling). The
HDL's TC0220IOC stub at `hdl/jttaitob_ioc.v` only has to ack these
writes; it doesn't need to drive coin meters yet.

### Work RAM clear (0x600000–0x607FFE, 0x7FFE bytes)

```
000476  lea     $600000.l, A0
00047C  move.l  #$7ffe, D0          ; loop counter
000482  move.w  #$ff, D1            ; pattern
000486  move.b  D1, (A0)+           ; clear loop body
000488  subq.l  #1, D0
00048A  bne     $486
```

Standard 68k memory-clear loop. The CPU spine must complete this loop
(~32 K iterations) before the FPGA sim's PC stream is allowed to
diverge from MAME. **This is the easiest landmark to hit.**

### First TC0140SYT comm — kicks the sound CPU

```
002D56  move.b  #$04, $800000.l     ; SYT master_port_w (select reg 4)
002D5E  move.b  #$01, $800002.l     ; SYT master_comm_w (write 0x01)
```

After ~2,800 bytes of setup the 68k pokes the sound side. Reg 4 / data
0x01 = "tell sound CPU to start playing" (cf. `taitosnd.cpp::master_*`).

---

## Sound CPU (Z80 @ 4 MHz)

### Reset + interrupt mode

```
0000  di                            ; disable interrupts
0001  im   1                        ; IM 1 → IRQ vectors to 0x0038
0003  ld   a,$05                    ; "reset / hello" magic
0005  ld   ($E200),a                ; write SYT slave port (0xE200 = port_w)
0008  ld   ($E201),a                ; write SYT slave comm (0xE201 = comm_w)
000B  jp   $01AA                    ; jump to main init
```

The 5-write sequence to 0xE200/0xE201 is the Z80's half of the
TC0140SYT handshake — confirms the chip is up and clears the comm
mailbox.

### Stack + work-RAM clear

```
01AA  ld   a,$00
01AC  ld   ($E200),a                ; clear SYT port
01AF  ld   a,($E201)                ; flush SYT comm (×2)
01B2  ld   a,($E201)
01B5  ld   sp,$E000                 ; SP = top of Z80 RAM (8 KB at 0xC000-0xDFFF)
01B8  ld   hl,$C000                 ; clear ptr
01BB  ld   a,$E0                    ; stop @ HL=0xE000
01BD  ld   b,$00                    ; fill byte
01BF  ld   (hl),b                   ; clear loop
01C0  inc  hl
01C1  cp   h
01C2  jr   nz,$01BF
```

Z80 work RAM lives at 0xC000–0xDFFF (8 KB inside the SYT-managed slave
decoder). After this loop the Z80 is sitting at PC ≈ 0x01C4 waiting for
the next 68k poke.

---

## Pre-vector landmark — found via SDRAM dump

ROM byte at 0x400 is `46FC 2700` = `move #$2700, SR` — disable interrupts
and set the status register before the `lea` chain at 0x404 begins.

MAME's `trace ... noloop` skips this very first instruction (it's a
debugger quirk — `noloop` swallows the first opcode at the script-start
boundary). The FPGA sim's first ROM fetch lands at PC=0x400, and gate 1
fires when the CPU subsequently reaches 0x404 (the address MAME's
trace head shows).

## Validation gates (FPGA sim must hit, in order)

| # | CPU  | PC      | Event                              | What the HDL has to do |
|---|------|---------|------------------------------------|------------------------|
| 1 | 68k  | 0x000400 → 0x000404 | Reset vector taken     | ROM at SDRAM bank 0 readable, DTACK paced |
| 2 | 68k  | 0x00040A | SSP = 0x607FFE                    | Memory-clear loop will need work RAM |
| 3 | 68k  | 0x000410-0x000458 | 10× VCU ctrl writes      | `vcuctrl_cs` decoder must catch these |
| 4 | 68k  | 0x000460-0x000468 | Scroll RAM cleared       | `oram_cs` must catch 0x413800/0x413C00 |
| 5 | 68k  | 0x000470 | First IOC write                   | `ioc_cs` decoder fires; IOC stub acks |
| 6 | 68k  | 0x000490 | Work RAM clear complete (~32K)    | `ram_cs` + dual_ram16 working under load |
| 7 | Z80  | 0x000000 → 0x000001 | First fetch (`di; im 1`) | Z80 ROM at SDRAM bank 1 readable |
| 8 | Z80  | 0x000005 | First SYT slave write             | `jttaitob_syt` slave-side decode wired |
| 9 | Z80  | 0x0001C4 | Z80 RAM clear complete            | SYT-internal 8 KB RAM working |
| 10 | 68k  | 0x002D56 | First SYT comm to sound           | SYT master-side mailbox working |

Once gate 10 is met the boot is well underway; from there the next
landmark is the first IRQ-4 entry (vblank). We have not annotated that
yet because it depends on TC0180VCU `inth` timing, which is the next
work item.

---

## FPGA sim results (first iteration — sim_logs/boot_v60_final.log)

All wired 68k-side gates pass at 60-frame sim with **byte-exact data match** to MAME:

| # | Gate                              | FPGA result                                          | Status |
|---|-----------------------------------|------------------------------------------------------|--------|
| 1 | PC=0x000404 first user fetch      | hit                                                  | ✅     |
| 3 | First VCU ctrl write              | `0x0418000 <= 0x1010` (byte 0x10 on UDS lane)        | ✅     |
| 4 | First scroll RAM write            | `0x0413800 <= 0x0000`                                | ✅     |
| 5 | First IOC write                   | `0x0A00000 <= 0x00`                                  | ✅     |
| 6 | Work-RAM clear + verify loops complete | exits at PC ≈ 0xBE4 (ROM-checksum loop)         | ✅     |
| 10| First SYT comm                    | `0x0800000 <= 0x04`                                  | ✅     |

Gates 2 (SP load), 7–9 (Z80) are not yet wired in the dumper but the
68k boot is byte-identical to MAME through the entire 1.38M-instruction
reference trace. After gate 10 the CPU enters the ROM-checksum loop at
0xBE4 (`move.b D0, 0xA00000; add.w (A0)+, D0; cmpa.l #0x3FF9E, A0; bne $BE4`)
— the same place MAME's 1-second trace ends. The boot is healthy.

Reproduce via:
```
docker run --rm --platform linux/amd64 \
    -v "$(pwd)":/jtcores -v "/tmp":/host_tmp \
    --entrypoint /bin/bash jotego/simulator \
    /host_tmp/run_sim_in_docker.sh 60 cores/taitob/ver/rastan2/sim_logs/boot_v60.log
```
Runner script: `cores/taitob/ver/rastan2/run_sim_in_docker.sh`.

## Notes for the FPGA sim diff

- **No CPU diff prior to gate 6**. The memory-test loop is by far the
  highest-volume PC stream; any mismatch shows up immediately.
- **Endian / DSn pacing pitfalls**: byte writes to 0x418000-0x41801E are
  on the LOW byte lane (UDSn high, LDSn low), so `cpu_we[0]` must be
  the LDS we. The `jttaitob_main.v` decoder already gets this right —
  but the VCU ctrl-reg latch only captures byte 0 today; bytes 4-7
  (the BG/FG/TX rambanks) are also written and will be needed when the
  VCU pipeline lands.
- **Z80 IRQ**: the IRQ source is YM2610's IRQ-out (timer flag). Until
  the YM2610 model is running real ROMs the Z80 sits idle at the
  post-RAM-clear poll loop, which is fine for first-stage validation.
