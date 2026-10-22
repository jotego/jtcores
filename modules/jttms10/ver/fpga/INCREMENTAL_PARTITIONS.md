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
The helper compares frozen source fingerprints and rejects changes outside an existing
`modules/jttms10/hdl/*.v` file. It also compares the seed/update compile-input
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
