# CPS3 CSV Sound Verilator Simulation

This folder contains a standalone Verilator simulation for `jtcps3_sound`.

It:

- reads CPU sound commands from `snd.csv`
- replays them against the RTL sound block
- fetches PCM bytes through the JTFRAME cache and burst-SDRAM path
- writes stereo signed 16-bit audio to a 48 kHz WAV file

Inputs:

- `snd.csv` — CPU sound command trace from MAME (`~/.mame/debug/sfiiin/snd.csv`)
- `sdram_bank1.bin` — SDRAM bank 1 image (symlinked from `../sfiiin/`)

Run:

```bash
cd cores/cps3/ver/csvsnd
bash ./sim.sh --wav sound.wav --timeout 30
```

Supported arguments:

- `--csv <path>`
- `--wav <path>`
- `--timeout <milliseconds>`
- `--strict-reads`

By default, CSV readback mismatches are reported as warnings so the write-driven
audio replay can continue. Use `--strict-reads` to restore fail-fast behavior.

This is a direct Verilator simulation. It is not a simunit test.
