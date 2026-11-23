#!/bin/bash
# Run one pull-request check on a native Gitea runner host.
# Called by .gitea/workflows/pull-request.yaml after setprj.sh is sourced
# in the job's checkout. See $JTFRAME/doc/gitea-ci.md
set -euo pipefail

JTCHECK_URL=https://github.com/jotego/jtcheck.git
JTCHECK_REV=e58c2945d91df7e5e8adad2086ca4533c2ea0b85
SKIP_SUBMODULES=modules/jt900h,modules/jtframe/target/pocket,modules/jt680x/crasm
COMMENT_MARKER='<!-- jtcores-affected-cores -->'

main() {
    local check="${1:-}"
    keep_api_token
    case "$check" in
        beta)      prepare_tree --no-submodules; check_beta ;;
        affected)  prepare_tree; check_affected ;;
        framework) prepare_tree; check_framework ;;
        simunit)   prepare_tree; check_simunit 1 1 ;;
        simunit-*of*)
                   shard_args "${check#simunit-}"
                   prepare_tree; check_simunit "$SHARD_INDEX" "$SHARD_COUNT" ;;
        lint)      prepare_tree; check_lint ;;
        -h|--help) usage ;;
        *)         usage >&2; return 1 ;;
    esac
}

usage() {
    cat <<'EOF'
Usage: gitea-pr.sh <check>

Checks: beta, affected, framework, simunit, simunit-KofN, lint

simunit-KofN runs the K-th of N slices of the unit simulations, for example
simunit-2of3. The last slice also runs the rotation suite.

Run from a JTCORES checkout with setprj.sh sourced. The affected check
needs GITEA_TOKEN, GITHUB_SERVER_URL, GITHUB_REPOSITORY and PR_NUMBER.
EOF
}

# The PR code must not see the Gitea token. Only the comment helper uses it.
keep_api_token() {
    API_TOKEN="${GITEA_TOKEN:-}"
    unset GITEA_TOKEN GITHUB_TOKEN
}

prepare_tree() {
    test -n "${JTROOT:-}" || fail "source setprj.sh first"
    cd "$JTROOT"
    export JTBIN="$JTROOT/release"
    git clean -ffdxq
    if [ "${1:-}" != --no-submodules ]; then
        git submodule sync --recursive --quiet
        git submodule update --init --recursive --force --depth 1 --jobs 4 --quiet
        git submodule foreach --recursive --quiet git clean -ffdxq
    fi
    mkdir -p "$JTBIN"
    echo "Testing $(git rev-parse HEAD) on $(hostname)"
    verilator --version || true
}

check_beta() {
    beta-checks.sh
}

check_framework() {
    jtframe --help > /dev/null
    "$JTFRAME/bin/jtsim-funcs-test.sh"
    make -C "$JTFRAME/verilator/tests/cabinet" test
    "$JTFRAME/bin/jtbin2mr-test.sh"
    "$JTFRAME/bin/simunit-all-test.sh"
    "$JTFRAME/devops/reg-cabs-test.sh"
    (cd "$JTFRAME/src/jtframe" && go test ./...)
    (cd "$JTFRAME/src/jtutil" && go test ./...)
}

# K and N from a KofN string
shard_args() {
    [[ "$1" =~ ^([1-9][0-9]?)of([1-9][0-9]?)$ ]] || fail "bad shard $1, use simunit-KofN"
    SHARD_INDEX="${BASH_REMATCH[1]}"
    SHARD_COUNT="${BASH_REMATCH[2]}"
    [ "$SHARD_INDEX" -le "$SHARD_COUNT" ] || fail "bad shard $1, K must not exceed N"
}

check_simunit() {
    local index="$1" count="$2" status=0
    simunit-all.sh --jobs "$(job_count)" --shard "$index/$count" || status=1
    if [ "$index" = "$count" ]; then
        python3 "$JTFRAME/ver/video/rotation/run.py" --suite || status=1
    fi
    return $status
}

check_lint() {
    local status=0
    lint-all.sh || status=1
    lint-mra.sh || status=1
    return $status
}

# Leave half of the host for its interactive users
job_count() {
    local jobs="${JTCI_JOBS:-$(( $(nproc) / 2 ))}"
    if [ "$jobs" -lt 1 ]; then jobs=1; fi
    echo "$jobs"
}

check_affected() {
    local work
    work="$(mktemp -d)"
    WORK_DIR="$work"
    trap 'rm -rf -- "$WORK_DIR"' EXIT
    jtframe --help > /dev/null
    get_jtcheck "$work"
    gitea_api files > "$work/changed.json"
    echo "Changed files: $(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$work/changed.json")"
    run_jtcheck "$work"
    output_value pull-request-comment < "$work/output" > "$work/comment.md"
    gitea_api comment "$work/comment.md" || echo "Warning: could not update the pull request comment"
}

get_jtcheck() {
    local work="$1"
    git init --quiet "$work/jtcheck"
    git -C "$work/jtcheck" fetch --quiet --depth 1 "$JTCHECK_URL" "$JTCHECK_REV"
    git -C "$work/jtcheck" checkout --quiet --detach FETCH_HEAD
}

run_jtcheck() {
    local work="$1"
    env "INPUT_REPOSITORY-PATH=$JTROOT" \
        "INPUT_CHANGED-FILES=$(cat "$work/changed.json")" \
        "INPUT_SKIP-SUBMODULES=$SKIP_SUBMODULES" \
        GITHUB_OUTPUT="$work/output" \
        node "$work/jtcheck/src/index.mjs"
}

# reads a name<<marker block written by jtcheck to GITHUB_OUTPUT
output_value() {
    local name="$1"
    awk -v name="$name" '
        !inside && index($0, name "<<") == 1 { marker = substr($0, length(name) + 3); inside = 1; next }
        inside && $0 == marker { exit }
        inside { print }'
}

gitea_api() {
    GITEA_API_TOKEN="$API_TOKEN" COMMENT_MARKER="$COMMENT_MARKER" python3 - "$@" <<'EOF'
import json, os, sys, urllib.request

base = "%s/api/v1/repos/%s" % (os.environ["GITHUB_SERVER_URL"].rstrip("/"), os.environ["GITHUB_REPOSITORY"])
pr = os.environ["PR_NUMBER"]
token = os.environ["GITEA_API_TOKEN"]

def call(method, path, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(base + path, data=data, method=method)
    req.add_header("Authorization", "token " + token)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=60) as rsp:
        return json.load(rsp)

def changed_files():
    files, page = [], 1
    while True:
        batch = call("GET", "/pulls/%s/files?limit=50&page=%d" % (pr, page))
        files += [f["filename"] for f in batch]
        if len(batch) < 50:
            return files
        page += 1

def comment(path):
    body = open(path).read()
    marker = os.environ["COMMENT_MARKER"]
    for old in call("GET", "/issues/%s/comments" % pr):
        if marker in (old.get("body") or ""):
            call("PATCH", "/issues/comments/%d" % old["id"], {"body": body})
            return
    call("POST", "/issues/%s/comments" % pr, {"body": body})

if sys.argv[1] == "files":
    print(json.dumps(changed_files()))
else:
    comment(sys.argv[2])
EOF
}

fail() {
    echo "gitea-pr.sh: $*" >&2
    exit 2
}

main "$@"
