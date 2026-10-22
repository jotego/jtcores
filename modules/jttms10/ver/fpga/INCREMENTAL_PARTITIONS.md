# Explicit CPU partition build flow

This flow is an opt-in two-build experiment for the DataStorm test appliance.
It keeps the preserved Qsys/QIP and Quartus database, then asks Quartus to
reuse the fitted top-level partition while resynthesizing a changed CPU
partition. It does not change timing constraints and it does not promise that
Quartus will preserve the top partition; the terminal partition reports and
compile log must prove what actually happened.

The CPU partition root is the Quartus short path
`QSYS_test_board:inst|jttms10_fpga_runner:jttms10_runner|jttms10_system:u_cpu`.
It includes the system CPU word engine and fabric. The existing Top root
partition remains assigned to `|`. Before each compilation, the helper runs a
Quartus project-open query and rejects the build unless it sees exactly Top
and CPU, with the expected roots, netlist types, and placement/routing
preservation settings.

First create a seed from a successful, positive-STA full build. The seed has
both Top and CPU set to SOURCE, so it establishes a fresh fitted database with
the explicit CPU boundary:

```bash
cd /path/to/checkout-with-reviewed-helper-and-RAM-repair
source setprj.sh
bash modules/jttms10/ver/fpga/build-runner-incremental.sh \
  /path/to/positive-full-parent /path/to/new-partition-seed partition-seed
```

After independently reviewing the seed image, all-corner STA, memory/ROM
inference, partition roots and reports, run a CPU-only source change from a
separate clean checkout carrying the same helper revision used for the seed.
The helper itself is included in the frozen source fingerprints: changing
`partition_build.py` or another tracked build helper after creating a seed
requires a new seed with the updated helper before a CPU update can use it.
The original `partition-update` mode compares frozen source fingerprints and
rejects changes outside an existing `modules/jttms10/hdl/*.v` file. It also
compares the seed/update compile-input
trees, allowing only the expected partition settings and changed CPU package
HDL to differ; QIP, generated system, SDC, microcode, and other packaged inputs
must remain identical. The raw manifests retain all generated files. The
`jttms10-generated/dispatch-model/` directory has eight exact allowlisted
Verilator executable/cache outputs whose hashes are reported separately as
transient compile-manifest deltas; all HDL and any unrecognized file in that
directory remain stable-input checks. It sets Top to POST_FIT and CPU to
SOURCE, clones the seed database, and runs the ordinary Quartus compile flow
against that database:

```bash
cd /path/to/changed-cpu-checkout
source setprj.sh
bash modules/jttms10/ver/fpga/build-runner-incremental.sh \
  /path/to/reviewed-partition-seed /path/to/new-cpu-update partition-update
```

Each successful result retains the standard frozen input and RBF certificate
used by the programming receipt, plus `v2-partition-stage-result.json`, which
binds the parent seed, QSF, preflight query, compile log, fresh reports, image,
compile-time record, allowed compiled-input delta, and exact source delta. It
also stores the separate transient-output hashes and actual partition-related
lines from fresh map/fit reports and the flow log. The receipt writer validates
this sidecar before accepting a partition-built image.

## CPU source-set and microcode changes

The `partition-seed` stage also supports a candidate CPU HDL file set that
differs from the full parent. It reconstructs only the runner's direct CPU
Verilog package from the selected source tree, removes parent-only CPU module
files and their direct QSF rows, and records the exact operation in
`v2-partition-seed-package-reconstruction.json`. It refuses stale-module
references in the preserved QIP, Qsys Tcl, Qsys source, or SDC, and requires
the runner Qsys component Tcl and those infrastructure files to remain byte
identical. This remains a SOURCE/SOURCE full compile; review the resulting
image and reports before using it as a seed.

For later CPU microcode changes, use the separate `partition-update-microcode`
stage from that reviewed seed. It sets Top to POST_FIT and CPU to SOURCE, and
uses the ordinary Quartus full-compile flow. It accepts CPU HDL plus only the
explicit allowlist `control.yaml`, `gfx_line.yaml`, `gfx.yaml`, `memory.yaml`,
and `tms10.yaml` under `modules/jttms10/ucode/`; at least one allowlisted YAML
must change. It reruns the checked-in `modules/jttms10/ver/build.sh`, verifies
the current fixed generated CPU payload set (`tms10.uc`, `tms10.vh`,
`tms10_param.vh`, `tms10_dispatch.hex`, `tms10_gfx.uc`, `tms10_gfx.vh`, and
`tms10_gfx_param.vh`) and every copy, and compares compiled input deltas
against those regenerated outputs. The only additional source-file exception
is `modules/jttms10/hdl/tms10_dispatch.hex`, and its bytes must exactly match
the independently regenerated `tms10_dispatch.hex` payload. Generated
listings, dispatch logs, and the exact dispatch-model build outputs are hashed
as non-compile diagnostics; typed updates record their deltas separately from
Quartus inputs. New or missing payloads,
changes to QIP/Qsys/Tcl/SDC, or any other source/input delta fail closed.
This mode does not use a CDB-only ROM update path and does not derive timing
expectations from YAML; those remain in the independent TI-derived Python
fixtures.

Both update modes require the reviewed SOURCE/SOURCE seed. A selected
partition assignment does not prove actual reuse: the fresh compile logs and
partition reports still need to show Top POST_FIT reuse, CPU SOURCE synthesis,
preserved memory inference, and passing all-corner STA.

The first update attempt from the reviewed `8a7d2b0` seed to CPU source
`92c7eba` stopped before Quartus because the dispatch-model Verilator build
rewrote eight cache/output files. The preserved failed attempt is under
`/nobackup/tasks/jtcores-144/artifacts/pc-dsj-cone/build-plan/partition-update-gfx-ram-real-1/`.
The focused classifier audit against those immutable seed/candidate manifests
is `partition-delta-filter/real-seed-failed-attempt-classifier-audit.json`.
That attempt did not produce an update compile or an image. The input filter is
being reviewed separately; because it changes a tracked helper, its first
update must use a seed built with the reviewed helper revision. The previous
seed's measured full-flow wall was 954.53s (Quartus compile 945.22s); that is
historical planning data, not a timing estimate for a new seed.

Do not call the update incremental merely because the mode was selected. The
fresh compile log and partition reports must show CPU SOURCE resynthesis and
Top POST_FIT reuse. Reject the result if Quartus disengages a partition,
performs a full fallback, or fails cross-partition/all-corner timing. A seed
is a full compile and the update can also fall back; report those actual costs
separately. Never relax SDC constraints to make the experiment pass.
