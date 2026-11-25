#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
workspace=$(mktemp -d)
trap 'rm -rf -- "$workspace"' EXIT
mkdir -p "$workspace/fakebin" "$workspace/jtframe/src/jtutil" "$workspace/run" "$workspace/state" "$workspace/private"

cat > "$workspace/fakebin/go" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out=
while (($#)); do
    if [[ "$1" == -o ]]; then
        out=$2
        shift 2
    else
        shift
    fi
done
cat > "$out" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CAPTURE_ARGS"
STUB
chmod +x "$out"
EOF
chmod +x "$workspace/fakebin/go"

run_case() {
    local -a env_args=(
        "PATH=$workspace/fakebin:$PATH"
        "JTFRAME=$workspace/jtframe"
        "REGRESSION_WORKSPACE=$workspace/run"
        "CAPTURE_ARGS=$workspace/args"
        "XDG_STATE_HOME=$workspace/state"
        "JOTEGO=$workspace/private"
    )
    : > "$workspace/args"
    env "${env_args[@]}" bash "$script_dir/regression-action.sh" >/dev/null
    got=$(tr '\n' ' ' < "$workspace/args")
    [[ "$got" == "regression --poll --publish-to gitea " ]] || { echo "arguments: $got" >&2; exit 1; }
}

run_case
