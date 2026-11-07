#!/bin/bash
# Run after setprj.sh. Keep host-specific diagnostics out of Actions output.

main() {
    local child= status=0 cancelled=0 diagnostic_dir
    if [[ -z "${REGRESSION_CONFIG:-}" || -z "${JOTEGO:-}" ]]; then
        echo 'Regression configuration and private storage secrets are required.'
        return 1
    fi
    umask 077
    diagnostic_dir="${XDG_STATE_HOME:-$HOME/.local/state}/jtcores-regression"
    if ! mkdir -p "$diagnostic_dir" 2>/dev/null; then
        echo 'Unable to create private runner diagnostics.'
        return 1
    fi
    local diagnostic_file="$diagnostic_dir/action-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}.log"
    local config_file="$REGRESSION_WORKSPACE/regression.yaml"
    if ! { printf '%s\n' "$REGRESSION_CONFIG" > "$config_file"; } 2>/dev/null; then
        echo 'Unable to write private regression configuration.'
        return 1
    fi
    trap 'stop_regression' INT TERM
    echo 'Polling for a build; detailed diagnostics stay on the runner.'
    if ! { (cd "$JTFRAME/src/jtutil" && go build -o "$REGRESSION_WORKSPACE/jtutil" .) > "$diagnostic_file" 2>&1; } 2>/dev/null; then
        echo 'Unable to build jtutil; diagnostics retained privately on the runner.'
        rm -f -- "$config_file" 2>/dev/null
        return 1
    fi
    if [[ "$cancelled" == 1 ]]; then
        rm -f -- "$config_file" 2>/dev/null
        return 130
    fi
    # Run the binary directly so TERM reaches its cancellation handler.
    # Do not set GH_TOKEN/GITHUB_TOKEN: gh uses the host account credentials.
    "$REGRESSION_WORKSPACE/jtutil" regression --poll --publish-to gitea --config "$config_file" >> "$diagnostic_file" 2>&1 &
    child=$!
    wait "$child" || status=$?
    # A signal can interrupt wait before jtutil finishes board cleanup.
    if kill -0 "$child" 2>/dev/null; then
        wait "$child" || status=$?
    fi
    trap - INT TERM
    rm -f -- "$config_file" 2>/dev/null
    if [[ "$status" == 0 ]]; then
        echo 'Poll finished. Campaign progress and reports are stored privately.'
    else
        echo 'Regression interrupted or failed; consult the Gitea report and private runner diagnostics.'
    fi
    return "$status"
}

stop_regression() {
    cancelled=1
    if [[ -n "$child" ]]; then
        kill -TERM "$child" 2>/dev/null || true
    fi
}

main "$@"
