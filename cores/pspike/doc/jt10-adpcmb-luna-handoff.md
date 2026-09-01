# JT10 ADPCM-B audio-fix experiment handoff

Use the Luna model. Work in `/Users/andreabogazzi/develop/jtpublicfork`.

## Goal

Apply and audition progressively larger JT10 ADPCM-B fixes. Turbo Force is the only core to simulate. For every variant, run the first 3000 frames and deliver both the WAV and an MP4 containing the simulator audio. Stop after each variant so Andrea can listen and decide whether to keep it or advance to the next fix. Do not substitute trace/statistical results for playable media.

Keep commentary extremely short; only report a failure, required decision, or completed artifacts.

## Known diagnosis

- Turbo Force sound, ADPCM-A and ADPCM-B ROM regions match MAME byte-for-byte.
- RTL and MAME produced the same 20 ADPCM-B starts, parameters, order and pacing.
- The requested ROM address and high/low-nibble order are correct.
- The decoder received 12 stale nibbles in 2,541 captured nibbles. Example: at byte `0x00c024`, MAME/ROM consumes `8,0` from byte `0x80`; RTL consumed `3,0` because the live bus still held stale byte `0x35` for the high nibble.
- `jt10_adpcm_drvB.v` currently makes `roe_n` a one-master-clock pulse:

  ```verilog
  always @(posedge clk) roe_n <= ~(adv & cen55);
  ```

- The JTFRAME gate waits on `pcmb_cs & ~pcmb_ok`, but `pcmb_cs = ~roe_n` disappears before SDRAM responds. Thus the gate stops waiting early.
- PSPike and F1GPR share `jtpspike_snd` and therefore share the fault.
- Temporary diagnostic RTL was already removed. Do not restore it unless a variant needs a small verification probe.

Relevant source:

- `/Users/andreabogazzi/develop/jtpublicfork/modules/jt12/hdl/adpcm/jt10_adpcm_drvB.v`
- `/Users/andreabogazzi/develop/jtpublicfork/cores/pspike/hdl/jtpspike_snd.v`
- `/Users/andreabogazzi/develop/jtpublicfork/cores/pspike/cfg/mem.yaml`
- Generated gate reference: `/Users/andreabogazzi/develop/jtpublicfork/cores/pspike/ver/game/jtpspike_game_sdram.v`
- Gate implementation: `/Users/andreabogazzi/develop/jtpublicfork/modules/jtframe/hdl/clocking/jtframe_gated_cen.v`

## Preserve existing work

Inspect `git status` first. Do not alter unrelated dirty/untracked files. At handoff time these included the F1GPR `.DS_Store`, `.claude/`, Rastan CAB files, `cores/tatono/`, an ARM64 jtframe binary, a `.simunit`, `sim-core.sh`, and `tools/`.

Do not commit. Use `apply_patch` for source changes. Keep each variant's patch and artifacts clearly named so the chosen variant can be restored exactly.

The existing baseline WAV is:

`/Users/andreabogazzi/develop/jtpublicfork/cores/pspike/ver/game/test.wav`

Copy it to the artifact directory as `v0-baseline.wav` before running another simulation.

## Suggested skills

- If a `sim-core` skill is available in this session, invoke it for simulation and MP4 generation. It was not present in the previous session, so the fallback command below is authoritative.
- Use `caveman` in `ultra` mode for terse progress and artifact delivery.

## Experiment protocol

Create `/private/tmp/jt10-adpcmb-audio-tests/` and preserve each result there. A simulation overwrites `test.wav` and `pspike_sim.mp4`, so copy them immediately after every run.

Run Turbo Force with frame image output enabled:

```bash
FRAMES=3000 FRAME_PNG=1 ./sim-core.sh pspike turbofrc -u JTFRAME_180SHIFT
```

Expected simulator outputs:

- `/Users/andreabogazzi/develop/jtpublicfork/cores/pspike/ver/game/test.wav`
- `/Users/andreabogazzi/develop/jtpublicfork/cores/pspike/ver/game/pspike_sim.mp4`

After each run, verify both files exist, are non-empty, and have sensible duration/audio streams. Copy them to the temporary artifact directory with the variant prefix. Deliver clickable absolute paths and render the WAV/MP4 inline if supported.

### Variant 1 — smallest fix: stretch ROM request

Change only the `roe_n` process in `jt10_adpcm_drvB.v` so it updates on an accepted JT10 `cen`. During an external memory wait, `cen` is suppressed and `roe_n` therefore stays asserted:

```verilog
always @(posedge clk or negedge rst_n)
    if( !rst_n )
        roe_n <= 1'b1;
    else if( cen )
        roe_n <= ~(adv & cen55);
```

Do not change the data path in this variant. Run 3000 frames and save:

- `v1-stretched-roe.wav`
- `v1-stretched-roe.mp4`
- `v1-stretched-roe.patch`

Deliver them and stop for Andrea's listening decision.

### Variant 2 — only after approval: atomic byte latch

Build on Variant 1. Add an internal `rom_byte` register. Capture `data` on the first accepted `cen` while `roe_n` is still low, then source both high and low nibbles from that same byte. This should mirror MAME's atomic byte buffer and prevent the bus from changing between nibbles.

Suggested shape (check nonblocking timing carefully):

```verilog
reg [7:0] rom_byte;

always @(posedge clk or negedge rst_n)
    if( !rst_n ) begin
        roe_n    <= 1'b1;
        rom_byte <= 8'd0;
    end else if( cen ) begin
        if( !roe_n )
            rom_byte <= data;
        roe_n <= ~(adv & cen55);
    end

always @(posedge clk) if(cen)
    din <= !nibble_sel ? rom_byte[7:4] : rom_byte[3:0];
```

Confirm that the initial byte is captured several ADPCM clocks before its first decode and that repeated samples restart cleanly. Run and save `v2-byte-latch.{wav,mp4,patch}`. Deliver and stop.

### Variant 3 — only if Variant 2 is insufficient

Propose before implementing. Add an explicit ADPCM-B request/valid handshake through JT10/JT12, latch a complete byte on `ok`, and consume it high-nibble then low-nibble like MAME. This changes JT10's public interface and all instantiations, so obtain Andrea's approval first. Preserve backward compatibility where practical.

## Acceptance

- Primary: Andrea hears clean Turbo Force attract-mode ADPCM-B in the delivered WAV/MP4.
- No missing/reordered samples or changed pacing.
- No regression in ADPCM-A/FM/PSG audio.
- Variant remains inside JT10 if feasible so PSPike, F1GPR and other JT10 users benefit.
- Keep the smallest variant that sounds correct.
