#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
workflow="$script_dir/../../../.gitea/workflows/hardware-regression.yaml"
grep -Fqx "      REGRESSION_LEGACY_SIDI128: \${{ github.event_name == 'schedule' || inputs.legacy_sidi128 || false }}" "$workflow"
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
    local optin=$1 want=$2
    local -a env_args=(
        "PATH=$workspace/fakebin:$PATH"
        "JTFRAME=$workspace/jtframe"
        "REGRESSION_WORKSPACE=$workspace/run"
        "REGRESSION_CONFIG={}"
        "CAPTURE_ARGS=$workspace/args"
        "XDG_STATE_HOME=$workspace/state"
        "JOTEGO=$workspace/private"
        "GITHUB_RUN_ID=$optin"
    )
    if [[ "$optin" != absent ]]; then
        env_args+=("REGRESSION_LEGACY_SIDI128=$optin")
    fi
    : > "$workspace/args"
    env "${env_args[@]}" bash "$script_dir/regression-action.sh" >/dev/null
    if grep -qx -- --legacy-sidi128 "$workspace/args"; then
        got=true
    else
        got=false
    fi
    [[ "$got" == "$want" ]] || { echo "opt-in=$optin forwarded=$got; expected=$want" >&2; exit 1; }
}

run_case absent false
run_case false false
run_case true true

if REGRESSION_LEGACY_SIDI128=maybe bash "$script_dir/regression-action.sh" >/dev/null 2>&1; then
    echo 'invalid legacy opt-in was accepted' >&2
    exit 1
fi
