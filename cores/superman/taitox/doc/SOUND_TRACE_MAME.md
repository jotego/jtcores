# Superman MAME Sound Trace — Boot Timeline

Captured via `mame_scripts/trace_sound.lua` on MAME 0.276 / setname `supermanu`.

Tapped:
  - 68k:  `0x800000-0x800003` (TC0140SYT master port + comm, R+W)
  - Z80:  `0xE200-0xE201`     (TC0140SYT slave port + comm, W only)

## First-event summary

| Tag           | Frame | PC      | Direction                    | Data |
|---------------|-------|---------|------------------------------|------|
| `syt_sport`   | 0     | z=0008  | Z80 → SYT slave PORT (write) | 0x05 |
| `syt_scomm`   | 0     | z=000B  | Z80 → SYT slave COMM (write) | 0x05 |
| `syt_mport`   | 69    | m=2DF6  | 68k → SYT master PORT (write)| 0x04 |
| `syt_mcomm`   | 69    | m=2DFC  | 68k → SYT master COMM (write)| 0xFF |
| `syt_mcomm_r` | 69    | m=2E16  | 68k ← SYT master COMM (read) | 0x04 |

## First real sound command

**Frame 76 (~1.27 s after boot)**, 68k issues the first command to slot 0:

```
frame=76  mPC=2DF6  68k W syt_master_PORT  data=04   ; (residual NMI-enable)
frame=76  mPC=2E16  68k R syt_master_COMM  data=04   ; (read status)
frame=76  mPC=2E1C  68k R syt_master_COMM  data=04
frame=76  mPC=2E0C  68k W syt_master_PORT  data=00   ; select slot 0
frame=76  mPC=2E16  68k R syt_master_COMM  data=00
frame=76  mPC=2E1C  68k R syt_master_COMM  data=0E
frame=76  mPC=2DF6  68k W syt_master_PORT  data=00   ; select slot 0 (entry)
frame=76  mPC=2DFC  68k W syt_master_COMM  data=EF   ; command byte
frame=76  mPC=2E04  68k W syt_master_COMM  data=0E   ; command byte
```

So the SYT command-send routine lives at **PC=0x002DF6..0x002E1C** (a 0x30-byte
window).  Sequence per send:

  1. write `PORT = slot_index` (0x00..0x03 = command slot; 0x04 = NMI ctrl)
  2. write `COMM = data_byte_0`
  3. write `COMM = data_byte_1`
  4. read  `COMM` to spin until ack
  5. write `PORT = 0x04` ; ack-clear

## Z80 boot init at frame 0

```
frame=0  zPC=0008  Z80 W syt_slave_PORT  data=05
frame=0  zPC=000B  Z80 W syt_slave_COMM  data=05
```

PC 0x0008 / 0x000B are the very start of the Z80 ROM — handshake fires
immediately on reset.  Writing 0x05 to **both** slave registers tells the
68k "I'm alive" and arms the master->slave NMI path on idx-5 trigger.

Note: our HDL's `jtsuperman_syt.v` initialises `nmi_en=0` and only enables
NMI when the Z80 writes idx 6.  MAME's Z80 writes idx 5 (not 6) at boot.
Confirm what `tc0140syt_device::slave_port_w(5)` actually does in MAME — it
may be the NMI-enable trigger we've been wiring to idx 6.

## What does not happen (frames 195 — 1200)

After frame ~194 the 68k goes quiet on the SYT.  No `syt_mport` / `syt_mcomm`
events fire for the rest of the trace (1200 frames captured).  Two
possibilities:

  - boot init completes around frame 194 and the 68k then doesn't issue
    music/SFX commands until coin-insert or attract-mode timeout
  - MAME's attract music is driven entirely by the Z80 from its own ROM
    after the 68k arms it once at boot

Either way, the **window where our FPGA must match MAME exactly** is
**frames 0 — 194**.  Past that, divergence is expected without input.

## Z80 SYT access is POLL-based, not NMI-based

In the full 30s attract trace, the Z80 NEVER writes `slave_port=0x06`
(NMI enable).  The only slave_port values written are:

  - `0x00` (zPC=01AF, 0276) — select command-slot 0 to read data
  - `0x04` (zPC=006D, 02D0) — select status register, then read

So the Z80 polls `status_reg` in a tight loop (zPC=006D/0070 and
zPC=02D0/02D3) and branches to command handling when `PORT01_FULL` or
`PORT23_FULL` is set.  NMI is left disabled (after Z80 boot writes
`slave_comm(submode=5)` at zPC=000B, NMI stays off for the entire trace).

This means **first sound does NOT depend on NMI**.  The chain is purely:
  1. 68k writes nibbles to slot 0 → `status[0]` (PORT01_FULL) goes high
  2. Z80 status-poll reads back status, sees bit set
  3. Z80 reads `comm` twice → returns slot 0/1 nibbles, clears `status[0]`
  4. Z80 dispatches command, writes to YM2610

Our `jtsuperman_syt.v` correctness on this path requires:
  - master_comm_w idx 1 sets `status_reg[0]`        ✓
  - master_comm_w idx 3 sets `status_reg[1]`        ✓
  - slave_comm_r  idx 1 clears `status_reg[0]`      ✓
  - slave_comm_r  idx 3 clears `status_reg[1]`      ✓
  - master idx 4 = slave reset (was idx 7 — FIXED)
  - no HLE echo on slave idx 3 (was forced — FIXED)
  - no HLE status patch on master idx 4 read (FIXED)

## Target for FPGA bring-up

1. Verify Z80 reaches PC=0x0008 / 0x000B at FPGA frame ≈ 0 and writes
   0x05 to `0xE200` and `0xE201`.  Check our `syt_slave_*` waveforms.
2. Verify 68k reaches PC=0x002DF6 by FPGA frame ≈ 69 and issues the
   PORT=0x04 / COMM=0xFF handshake.
3. If 68k never reaches PC=0x002DF6, the bug is upstream of sound — it's
   in the 68k boot path, not in our SYT/YM2610 logic.

## Comparison at frames 465-467 (user-flagged)

MAME has **no SYT activity** at frames 465-467 — the 68k boot is long done
and attract is running without sound commands.  If our FPGA at frame
465-467 is doing something interesting on SYT, it's a *delayed* version of
the boot init that MAME completed at frame ~194.  Compare 68k PC + Z80 PC
between MAME[frame=465] and FPGA[frame=465] to see what's running.

## Reproduce

```
cd $HOME/Emus/mame0276-arm64 && \
  ./mame -rompath $HOME/.mame/roms supermanu \
    -autoboot_script $JTROOT/cores/superman/ver/superman/mame_scripts/trace_sound.lua \
    -autoboot_delay 0 -seconds_to_run 30 \
    -video none -sound none -nothrottle

# trace written to /tmp/superman_sound_trace.log
```
