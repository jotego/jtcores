# TMS34010 FPGA regression adapter

This folder contains the bounded protocol-v5 FPGA runner, its host transport,
and the independent TI-derived timing checker used to inspect short captures.
The #149 CPU implementation and its timing schedule are the hardware under
study. Expected registers, bus events, and durations come only from the frozen
#144 checker at commit `9a17778b941dce89328316ee3e8f7f0a4bd14923`; candidate
YAML is never an oracle.

`run_batch.py` takes `--source-root` for the frozen expectation checkout and
`--hardware-source-root` for the #149 checkout whose CPU/runner sources and
programmed-image receipt must match. Before any remote access, it verifies the
pinned expectation-source manifest and separately checks the candidate source,
runner, and image identities.

The host-only identity tests need both source roots and use no board access:

```sh
JTROOT=/path/to/jtcores-149 \
JT_TMS10_ORACLE_ROOT=/path/to/frozen-9a17778b \
python3 -m unittest modules/jttms10/ver/fpga/test_hardware_oracle_identity.py
```

`ver/build.sh` generates the candidate CPU microcode and dispatch inputs and
runs the source-level decoder/GFX checks. `build-runner.sh` prepares a fresh
Quartus project from the supplied vendor archive, generates the CPU inputs,
and adds the bounded runner. `build-runner-incremental.sh` is for the narrowly
certified incremental flow described in `INCREMENTAL_PARTITIONS.md`; it still
requires a successful full-fit parent. The runner’s `JTTMS10_REGRESSION`
observation taps are compile-time gated and do not alter normal CPU logic.

No current board image was fitted or programmed as part of this adapter work.
The short Verilator `nop_hit` smoke case passes the frozen checker, while the
cache-disabled `nop_off` case remains a known failure: 22 observed INCLK versus
32 expected, with fetch/read timing mismatches. CD byte-store timing coverage
also remains a known-failure area until a candidate passes the unchanged
independent checker. ROM-update receipts are unsupported; use only receipts
from the explicitly validated full-build or certified incremental flows.
