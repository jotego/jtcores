# CPS3 BIOS test firmware

This folder builds a minimal encrypted CPS3 BIOS image for issue #39.  The
program runs from the security-cart BIOS window, initializes only the SH-2 bus
width register and the SS layer state needed for text, then displays:

```text
BIOS TEST
```

The generated BIOS uses the `sfiiin` key bytes already supported by the CPS3
MRA header:

```text
key1 = b5fe053e
key2 = fc03925a
```

Build the quick BIOS smoke test with:

```bash
source setprj.sh
cd cores/cps3/firmware
./build.py
```

Build the deeper system-check diagnostic target with:

```bash
source setprj.sh
cd cores/cps3/firmware
env -u MISTERPASSWD ./build.py --target syscheck
jtutil rom cps3_syscheck.mra --path build
```

The `syscheck` firmware is the first issue #40 diagnostic target. It keeps a
compact result block at `0x02070000`, runs smoke read/write checks for main RAM,
palette RAM, and SS map RAM, verifies DIP readback, and displays live raw input
state for the four CPU-visible input halfwords plus DIP select/readback on the
SS layer.

Outputs are written under `build/`:

For the default `bios_test` target:

- `bios_test_plain.bin`: plaintext 512 KiB BIOS image.
- `bios_test.29f400.u2`: encrypted 512 KiB BIOS payload used by the MRA and jtutil rom flow.
- `cps3_bios_test.zip`: MiSTer-ready zip containing `bios_test.29f400.u2`.
- `cps3_bios_test.mra`: ad-hoc MiSTer MRA using `jtcps3.rbf`.

For `--target syscheck`:

- `syscheck_plain.bin`: plaintext 512 KiB BIOS image.
- `syscheck.29f400.u2`: encrypted 512 KiB BIOS payload used by the MRA and jtutil rom flow.
- `cps3_syscheck.zip`: MiSTer-ready zip containing `syscheck.29f400.u2`.
- `cps3_syscheck.mra`: ad-hoc MiSTer MRA using `jtcps3.rbf`.

## Simulation

Build the MRA ROM with `jtutil rom`, then simulate it from the CPS3 BIOS test verification folder:

```bash
source setprj.sh
cd cores/cps3/firmware
env -u MISTERPASSWD ./build.py
jtutil rom cps3_bios_test.mra --path build
cd ../ver/cps3_bios_test
ln -srf $ROM/cps3_bios_test.rom rom.bin
jtsim -time 20 -load -w
```

## Copy to MiSTer

`build.py` can deploy the generated files to `mister.home` after a successful
build. This is disabled by default. To enable it, define `MISTERPASSWD` with the
MiSTer root password before running the build:

```bash
MISTERPASSWD=... ./build.py
```

When `MISTERPASSWD` is set, `build.py` runs `copy_to_mister()` and copies:

- `build/cps3_bios_test.zip` to `root@mister.home:/media/fat/games/mame/`
- `build/cps3_bios_test.mra` to `root@mister.home:/media/fat/_JTBIN/`
- `$JTROOT/release/mister/jtcps3.rbf` to
  `root@mister.home:/media/fat/_JTBIN/cores/`, only if the RBF exists

The copy uses `sshpass -e scp`, so the password is passed through the `SSHPASS`
environment variable created internally by the script.
