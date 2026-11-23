#!/bin/bash
# Register and run the native Gitea pull-request runner as a systemd user
# service. Run as the runner user, without sudo, after gitea-runner-deps.sh.
# See modules/jtframe/doc/gitea-ci.md

NAME=jtcores-pr-runner
DIR="$HOME/.local/share/$NAME"
UNIT="$HOME/.config/systemd/user/$NAME.service"
INSTANCE="${GITEA_INSTANCE:-http://gitea.jotego.es}"
LABEL=jtcores-host
VERILATOR_BIN=/nobackup/jtmisc/verilator/current/bin

main() {
    set -euo pipefail
    case "${1:-}" in
        register) shift; register "$@" ;;
        config)   write_config; write_unit; restart ;;
        status)   systemctl --user status "$NAME" --no-pager ;;
        -h|--help) usage ;;
        *) usage >&2; return 1 ;;
    esac
}

usage() {
    cat <<EOF
Usage: gitea-runner.sh register [--token-file FILE]
       gitea-runner.sh config
       gitea-runner.sh status

register  registers this host in $INSTANCE with the label $LABEL and
          installs the $NAME systemd user service. The registration token
          comes from the jtcores repository settings, Actions, Runners.
          It is read from FILE or prompted for. Never pass it as an argument.
config    rewrites the configuration and service files and restarts it
status    shows the service state
EOF
}

register() {
    local token
    token="$(read_token "$@")"
    if [ -e "$DIR/.runner" ]; then
        echo "$DIR/.runner exists: the host is registered already. Use config to update it."
        return 1
    fi
    write_config
    local runner
    runner="$(find_runner)"
    (cd "$DIR" && "$runner" register --no-interactive --config "$DIR/config.yaml" \
        --instance "$INSTANCE" --token "$token" --name "$(hostname -s)-pr" --labels "$LABEL:host")
    write_unit
    restart
}

read_token() {
    local token=""
    if [ "${1:-}" = --token-file ]; then
        token="$(tr -d '[:space:]' < "$2")"
    else
        read -r -s -p "Gitea runner registration token: " token
        echo >&2
    fi
    test -n "$token" || { echo "Empty token" >&2; return 1; }
    echo "$token"
}

find_runner() {
    local runner
    for runner in /usr/local/bin/act_runner "$HOME/.local/bin/act_runner"; do
        if [ -x "$runner" ]; then echo "$runner"; return; fi
    done
    echo "act_runner not found. Run gitea-runner-deps.sh with sudo first." >&2
    return 1
}

runner_path() {
    echo "$VERILATOR_BIN:$HOME/.local/bin:/usr/local/go/bin:$HOME/go/bin:/usr/local/bin:/usr/bin:/bin"
}

write_config() {
    local work="/tmp/jtcores-$(id -u)/gitea-runner"
    mkdir -p "$DIR" "$work"
    chmod 700 "$DIR"
    cat > "$DIR/config.yaml" <<EOF
log:
  level: info
runner:
  file: $DIR/.runner
  # one job at a time: hosts are shared with interactive users
  capacity: 1
  envs:
    HOME: $HOME
    PATH: $(runner_path)
    XDG_CONFIG_HOME: $HOME/.config
    JTCI_ROOT: $work/ci
  timeout: 3h
  shutdown_timeout: 2m
  # act_runner ignores a fetch that times out, but Gitea has assigned the
  # task by then and the job never runs. Gitea can take over 5 s to answer
  fetch_timeout: 60s
  fetch_interval: 5s
  labels:
    - $LABEL:host
cache:
  enabled: false
container:
  require_docker: false
host:
  workdir_parent: $work/work
EOF
}

write_unit() {
    local runner
    runner="$(find_runner)"
    mkdir -p "$(dirname "$UNIT")"
    cat > "$UNIT" <<EOF
[Unit]
Description=JTCORES native Gitea pull-request runner
After=network-online.target

[Service]
WorkingDirectory=$DIR
ExecStart=$runner daemon --config $DIR/config.yaml
Environment=HOME=$HOME
Environment=PATH=$(runner_path)
UnsetEnvironment=VERILATOR_ROOT
Restart=always
RestartSec=10
TimeoutStopSec=150
UMask=0077

[Install]
WantedBy=default.target
EOF
}

restart() {
    systemctl --user daemon-reload
    systemctl --user enable "$NAME" > /dev/null
    systemctl --user restart "$NAME"
    systemctl --user --no-pager --lines 5 status "$NAME"
}

main "$@"
