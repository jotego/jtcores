# Pull-request checks on Gitea

GitHub runs the full CI, including all core compilations. The office Gitea
server (`http://gitea.jotego.es/jotego/jtcores`) runs the lighter checks on
pull requests with `.gitea/workflows/pull-request.yaml`. Core compilations
stay on GitHub.

| Check          | Commands                                                           | GitHub workflow       |
|----------------|--------------------------------------------------------------------|-----------------------|
| `beta`         | `beta-checks.sh`                                                   | `beta-checks.yml`     |
| `affected`     | jotego/jtcheck, comment on the pull request                        | `affected-cores.yaml` |
| `framework`    | jtsim/cabinet/jtbin2mr/reg-cabs/simunit-all tests, `go test ./...` | `framework.yaml`      |
| `simunit-KofN` | `simunit-all.sh --shard K/N`, rotation suite in shard N            | `simunit.yaml`        |
| `lint`         | `lint-all.sh`, `lint-mra.sh`                                       | `linter.yaml`         |

Each check is one matrix job, so Gitea spreads them over the registered hosts.
The unit simulations are the longest check, so they are split into three
shards, `simunit-1of3` to `simunit-3of3`, which run `simunit-all.sh --shard K/N`.
`simunit-all.sh` reads the test durations in `$JTFRAME/ver/simunit-times.txt`
to start the longest tests first and to give each shard a similar total time.
Tests missing from the file count as 30 s. To change the number of shards, edit
the matrix only.

Gitea queues the jobs of a run in name order, so the shards start after the
short checks and each runner, which takes one job at a time, ends the run on a
shard. Use one shard per runner host. The longest test, which takes up to 16
minutes on a loaded host, limits how short a run can be. Refresh the durations
after adding long tests:

```bash
GITHUB_ACTIONS=true simunit-all.sh --jobs 4 --save-times $JTFRAME/ver/simunit-times.txt
```
The jobs run directly on the hosts, without Docker, through
`modules/jtframe/devops/gitea-pr.sh <check>`. That script can also be run by
hand from any checkout after sourcing `setprj.sh`.

Differences from GitHub:

- Gitea tests the pull-request head commit, GitHub the merge commit.
- GitHub runs each unit simulation as its own job. Here each shard runs its
  slice in one job, using half of the host CPUs (`JTCI_JOBS` overrides it).
  The log tail of a failed test is printed after its FAIL line. Tests that skip
  on GitHub skip here too because act_runner sets `GITHUB_ACTIONS=true`.
- Jobs run under `nice -n 10` because the hosts are also used interactively.

## Checkouts

The workflow does not use `actions/checkout`. Each host keeps one checkout per
check under `$JTCI_ROOT/<check>` (default `/tmp/jtcores-<uid>/gitea-runner/ci`),
so submodules are not cloned again for every pull request. The simunit shards
share the `simunit` checkout. A job fetches `refs/pull/<n>/head` with depth 2
(some Go tests read `HEAD~1`) and the job token, scoped to the Gitea URL. If the
fetch or the checkout fails, for example because the system removed old files
from `/tmp`, the job clears the folder and clones again. The job fails as
superseded when the pull request no longer points to the commit of the run, so
all jobs of a run test the same commit. `gitea-pr.sh` then removes every
untracked and ignored file, including submodule ones, and updates the
submodules with depth 1. A lock file serializes jobs that share a checkout. The
directory is disposable: delete it to force a fresh clone.

When a run is cancelled, act_runner kills only the step's shell. A watchdog
started by the step then stops every process left in the step's session, so
simulations do not keep running or holding the checkout lock.

The affected-cores check reads the changed files from the Gitea API and runs
jtcheck at the commit pinned in `gitea-pr.sh`. It creates or updates one
comment marked `<!-- jtcores-affected-cores -->`, which needs
`pull-requests: write`. `gitea-pr.sh` removes the job token from the
environment before the checks run, so that tools do not pass it on by accident.
This is not a security barrier: `setprj.sh` and `gitea-pr.sh` come from the
pull request and run while the token is set.

jtcheck takes about 45 seconds on an idle host. Most of it is spent regenerating
the MMR files of every core for each core.

## Runner hosts

Hosts run act_runner 0.2.13 in host mode, as a systemd user service called
`jtcores-pr-runner` with the label `jtcores-host:host`. It is separate from the
`regression-host` runner on once.local described in `hardware-regression.md`.
Each runner takes one job at a time.

Pull-request code runs with the runner user's permissions, which includes its
SSH keys, tokens and NFS access. Only trusted accounts must be able to open pull
requests in the jotego/jtcores Gitea repository.

### Tools

| Tool       | Version  | Location                                    |
|------------|----------|---------------------------------------------|
| Verilator  | 5.050    | `/nobackup/jtmisc/verilator/current/bin` (NFS) |
| Go         | 1.23.4   | `/usr/local/go/bin`                         |
| Icarus     | 13       | `/usr/local/bin`                            |
| yq         | 4.47.2   | `/usr/local/bin` (mikefarah)                |
| Node.js    | Ubuntu   | `/usr/bin` (jtcheck)                        |
| act_runner | 0.2.13   | `/usr/local/bin`                            |

All hosts use the same Verilator install from NFS. Releases go in
`/nobackup/jtmisc/verilator/<version>`, built with
`./configure --prefix=/nobackup/jtmisc/verilator/<version>` and `make install`.
`current` is a symbolic link to the release in use. Do not set
`VERILATOR_ROOT` with these installed trees. To upgrade, install the new
release in its own folder and then move the `current` link, so running
simulations keep a complete tree.

### Adding a host

1. Install the system packages, yq, act_runner and user lingering:

   ```bash
   sudo modules/jtframe/bin/install/gitea-runner-deps.sh
   ```

2. Get a registration token from the repository settings: Actions, Runners,
   Create new runner. Then register and start the service as the runner user:

   ```bash
   modules/jtframe/bin/install/gitea-runner.sh register
   ```

   The command prompts for the token. `--token-file FILE` reads it from a file.

`gitea-runner.sh config` rewrites the configuration and service files and
restarts the runner. `gitea-runner.sh status` shows the service state. Logs are
available with `journalctl --user -u jtcores-pr-runner`.
