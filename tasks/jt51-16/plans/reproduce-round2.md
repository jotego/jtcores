# Reproduce the powered follow-up

The correction is private JT51 commit
`e868314898b53cf734cef0e5c2c878aaa46f091e`, published on Gitea `master` and
`jt51-16`. The parent `.gitmodules` intentionally retains the public GitHub URL;
the new revision needs the private override. Shared Git configuration was not
changed. Use a clean checkout of the published parent `jt51-16` checkpoint.

For an uninitialized submodule:

```sh
git -c submodule.modules/jt51.url=ssh://git@archivo.local:2222/jotego/jt51.git \
    submodule update --init --checkout -- modules/jt51
git -C modules/jt51 rev-parse HEAD
```

For an existing clean submodule, fetch the private branch first, then select
the parent's exact gitlink without an additional public fetch:

```sh
git -C modules/jt51 fetch --no-tags \
    ssh://git@archivo.local:2222/jotego/jt51.git refs/heads/jt51-16
git submodule update --no-fetch --checkout -- modules/jt51
git -C modules/jt51 rev-parse HEAD
```

The result must be `e868314898b53cf734cef0e5c2c878aaa46f091e`. The existing
initialized fetch/remote revision was verified; these fresh-checkout commands
were reviewed, not executed as a new clone during publication.

Run the committed public suite from the parent root with a fresh absolute
artifact directory:

```sh
JT51_SILICON_BUILD=/nobackup/tasks/jt51-16-reproduce/artifacts/silicon \
    bash modules/jt51/ver/silicon/sim.sh all
```

The final dispatch contains405 checks. Recorded validation used the full339
pre-mirror run, then93 shared-helper checks and66 mirrored checks on the final
source. The246 legacy definitions and HDL stayed unchanged. The19-bit baseline
fails exactly five checks in each mixing group; all positives/coverage/history
controls pass. No final monolithic405 run is claimed. Individual final groups
are `mixing` and `mixing_mirror`.

[The result report](../RESULTS.md) records the physical triplicates, finite raw
reference-bin coverage limits, source/capture hashes and integration results.
The new archive is
`/gdrive/jotego/reverse/YM2151/2026-10-18-jt51-16-round2/`.
Its source tar contains the exact committed HDL and public tests, independently
compared byte-for-byte to Git. Analysis archives contain the frozen Python
observers, model harness, literal monitor programs, input bindings and per-file
SHA256 manifests. Raw archive paths/record identities remain distinct from the
historical campaign. Do not reinterpret the failed short-window observers with
new tolerances.

The full-tree linter used only the Verilator5.018 `--quiet-stats` presentation
compatibility wrapper documented in
[the original reproduction guide](../../jt51-14/plans/reproduce.md).
Its four unrelated baseline errors/two warnings remain; no diagnostic names
JT51. The correction is not a claim that those cores or compound Rastan pass.
