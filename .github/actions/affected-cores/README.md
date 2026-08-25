# JTCORES affected cores

This dependency-only action reports the JTCORES cores that may use a set of
changed files. For every core it runs the authoritative command
`jtframe files plain <core>` and compares the resulting list to the pull
request's changed paths. It has no npm dependencies or build step.

The checkout must include recursive submodules, and the runner needs Go to run
JTFRAME. The supplied JTCORES workflow uses `actions/setup-go` and
`actions/checkout` with `submodules: recursive`.

## Inputs

- `repository-path`: checked-out JTCORES root, default `.`.
- `changed-files`: newline-delimited, repository-relative file paths. This is
  useful for local invocation and is preferred when supplied.
- `base-sha`, `head-sha`: git revisions used to collect changed files when
  `changed-files` is absent.

## Outputs

- `affected-cores`: JSON object: core name to changed build inputs.
- `affected-core-names`: JSON array of core names.
- `unmatched-files`: changed paths with no resolved core dependency.
- `unresolved-cores`: cores JTFRAME could not resolve, including the error.
- `report`: Markdown table used in the GitHub job summary.
- `pull-request-comment`: Markdown body for the workflow's tagged
  pull-request comment.

## Local use

```bash
cd .github/actions/affected-cores
node --test
node src/cli.mjs --repo ../../.. --changed-files $'cores/cninja/hdl/jtcninja_decospr.v'
node src/cli.mjs --repo ../../.. --base <base-sha> --head HEAD
```

JTFRAME is responsible for the YAML, macro, glob, alias, nested-config, and
MMR-generated-source semantics. For cores with `cfg/mmr.yaml`, the action runs
`jtframe mmr <core>` in a temporary overlay before resolving the file list. It
also supplies a temporary MRA-header placeholder when necessary. Generated
`*_mmr.v` and `*_header.v` files are excluded before dependency matching: they
cannot be changed directly by a pull request. The action only performs path
matching and reports the result.

When Git reports a submodule gitlink change, such as `modules/jt900h`, the
action treats all files beneath that submodule as potentially changed.

## Pull-request comment

The workflow uses
[`thollander/actions-comment-pull-request`](https://github.com/marketplace/actions/comment-pull-request)
with `comment-tag: jtcores-affected-cores` and `mode: upsert`. This stable tag
updates one existing comment instead of posting duplicates. Each core is bold
and its affected inputs are listed by filename only.
