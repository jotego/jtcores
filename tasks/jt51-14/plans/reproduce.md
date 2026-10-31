# Reproduce the private JT51 correction

The corrected JT51 revision is `31c64cf19c8cdc669aa7f4b6b7d8a196f50cae3d`,
published on Gitea branch `jotego/jt51:jt51-14`. It has not been pushed to
GitHub. The parent `.gitmodules` deliberately retains the public GitHub URL.
A fresh checkout or CI job therefore needs an explicit private URL for this
revision. Existing shared Git configuration is unchanged. See the
[completed validation and limits](../RESULTS.md).

## Fresh private jtcores checkout

Run this after the parent `jtcores:jt51-14` publication. Use the published
parent commit when an immutable source checkout is required. These commands
initialize JT51 only; whole-core builds also require their other dependencies.
Gitea SSH access is required.

```sh
git clone --branch jt51-14 --no-recurse-submodules \
    ssh://git@archivo.local:2222/jotego/jtcores.git \
    /nobackup/tasks/jt51-14-reproduce/jtcores
cd /nobackup/tasks/jt51-14-reproduce/jtcores
git -c submodule.modules/jt51.url=ssh://git@archivo.local:2222/jotego/jt51.git \
    submodule update --init --checkout -- modules/jt51
git ls-tree HEAD modules/jt51
git -C modules/jt51 rev-parse HEAD
```

Both revisions shown for JT51 must be
`31c64cf19c8cdc669aa7f4b6b7d8a196f50cae3d`. The temporary scalar configuration
key is `submodule.modules/jt51.url`: `modules/jt51` is the submodule name,
including its slash. `-c` applies to that command and its child Git processes;
it does not edit `.gitmodules` or the existing shared configuration. The fresh
clone command itself was not executed as part of this publication check.

## Already initialized JT51 submodule

First select the published parent commit and ensure the submodule has no
uncommitted work. Fetch directly from Gitea, then update to the parent's exact
gitlink without another fetch:

```sh
git -C modules/jt51 fetch --no-tags \
    ssh://git@archivo.local:2222/jotego/jt51.git refs/heads/jt51-14
git submodule update --no-fetch --checkout -- modules/jt51
git ls-tree HEAD modules/jt51
git -C modules/jt51 rev-parse HEAD
```

The explicit URL avoids the initialized submodule's existing GitHub `origin`.
Do not substitute `-c remote.origin.url=... fetch origin`: remote URLs are
multivalued, so the old URL can still be chosen. The saved read-only check
confirmed that behavior; that attempted dry-run failed to find the private
branch. The corrected explicit-Gitea-URL fetch dry-run exited0. The scalar
fresh-initialization key was checked with `git config --get`. No fresh clone,
submodule update, configuration edit or additional test execution was performed
for these documentation checks. Normal CI submodule initialization without the
private override cannot be described as validated for this unpublished-to-GitHub
revision.

## Run the committed regression sources

From the parent checkout, use an absolute fresh build directory:

```sh
cd modules/jt51
JT51_SILICON_BUILD=/nobackup/tasks/jt51-14-reproduce/artifacts/silicon \
    bash ver/silicon/sim.sh all
```

The committed inputs are the four corrected files under `hdl/` and
`ver/silicon/{test.cpp,sim.sh,README.md}` at the revision above. The completed
validation consists of227 full-suite checks plus19 supplemental CSM checks
against the same final HDL, all passing. The final committed `all` dispatch
includes those supplemental checks. Archived feature rechecks retain their
original bands and explicit applicability limits. The existing PM source is
`ver/jt51_pm/sim.sh`; its recorded PASS is bounded by its unchanged stimulus.
The [results](../RESULTS.md) and [lint triage](lint-triage.md) bind those outcomes;
these instructions do not claim a new execution or whole-chip conformance.

## Verilator5.018 integration compatibility

The installed Verilator5.018 rejects JTFRAME's `--quiet-stats`. The recorded
lint/build runs used a task-local wrapper that removes only this exact
presentation flag, unsets the wrapper's `VERILATOR_ROOT`, and invokes the same
installed executable with every other argument unchanged. It adds no warning
suppression and changes no RTL. The exact wrapper used was:

```python
#!/usr/bin/env python3
import os,sys
args=[a for a in sys.argv[1:] if a != '--quiet-stats']
os.environ.pop('VERILATOR_ROOT',None)
os.execv('/home/jtejada/verilator/bin/verilator',
         ['/home/jtejada/verilator/bin/verilator']+args)
```

Store it as `bin/verilator` under a fresh task-local compatibility directory,
make it executable, and set `VERILATOR_ROOT` to that directory when invoking
JTFRAME. On another workstation, change only the absolute executable path to
the intended installed Verilator. The standalone public suite above already
checks support for its separate optional `--quiet` flag.

After sourcing `setprj.sh` from the parent project root, the recorded integration
commands are `lint-all.sh` and `jtcore contra -mrq`, with the compatibility
wrapper selected. Lint completed18 JT51 consumers, but the whole-tree command
exited1 because59 dependency paths and two `rest.bin` inputs were missing.
The [main report](../RESULTS.md) records the final Contra build status separately.
The private-source override and tool wrapper do not make blocked cores or an
unexecuted fresh CI job pass.
