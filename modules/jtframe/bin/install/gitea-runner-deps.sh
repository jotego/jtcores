#!/bin/bash
# System packages for a native Gitea Actions runner host (Ubuntu 24.04, amd64)
# Run once per host with sudo:
#   sudo modules/jtframe/bin/install/gitea-runner-deps.sh [runner-user]
# The runner user defaults to the account that called sudo.
# Then register the runner without sudo with gitea-runner.sh
# See modules/jtframe/doc/gitea-ci.md

YQ_VERSION=v4.47.2
YQ_SHA256=1bb99e1019e23de33c7e6afc23e93dad72aad6cf2cb03c797f068ea79814ddb0
ACT_RUNNER_VERSION=0.2.13
ACT_RUNNER_SHA256=3acac8b506ac8cadc88a55155b5d6378f0fab0b8f62d1e0c0450f4ccd69733e2
# same Go version as jotego_20.04.sh
GO_VERSION=1.23.4
GO_SHA256=6924efde5de86fe277676e929dc9917d466efa02fb934197bc2eba35d5680971

main() (
    set -euo pipefail
    check_host
    local runner_user="${1:-${SUDO_USER:-}}"
    test -n "$runner_user" || fail "give the runner user name as argument"
    id "$runner_user" > /dev/null || fail "unknown user $runner_user"
    install_tmp="$(mktemp -d /tmp/jtcores-runner-install.XXXXXX)"
    trap 'rm -rf -- "$install_tmp"' EXIT
    install_packages
    install_go
    install_yq
    install_act_runner
    enable_linger "$runner_user"
    echo "Done. Now run as $runner_user: modules/jtframe/bin/install/gitea-runner.sh register"
)

check_host() {
    test "$(id -u)" = 0 || fail "run with sudo"
    case "$(uname -m)" in
        x86_64|amd64) ;;
        *) fail "only amd64 hosts are supported" ;;
    esac
}

install_packages() {
    apt-get update
    # nodejs: jtcheck (affected cores). python3-pil: rotation suite
    # parallel: simunit-all.sh. bsdextrautils: column for lint-all.sh
    apt-get install --yes git curl util-linux nodejs parallel python-is-python3 \
        python3-pil bsdextrautils build-essential
}

# some unit simulations run Go generators that need a recent toolchain
install_go() {
    if /usr/local/go/bin/go version 2>/dev/null | grep -q "go$GO_VERSION "; then return; fi
    local file="$install_tmp/go.tar.gz"
    curl -fsSL -o "$file" "https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz"
    echo "$GO_SHA256  $file" | sha256sum --check --quiet || fail "checksum mismatch for Go $GO_VERSION"
    rm -rf /usr/local/go
    tar -C /usr/local -xzf "$file"
    echo "Installed Go $GO_VERSION in /usr/local/go"
}

# mikefarah yq, used by beta-checks.sh. Ubuntu's yq package is a different tool
install_yq() {
    if yq --version 2>/dev/null | grep -q "mikefarah.*version $YQ_VERSION"; then return; fi
    download "https://github.com/mikefarah/yq/releases/download/$YQ_VERSION/yq_linux_amd64" \
        "$YQ_SHA256" /usr/local/bin/yq
}

install_act_runner() {
    if act_runner --version 2>/dev/null | grep -q "v$ACT_RUNNER_VERSION\$"; then return; fi
    download "https://dl.gitea.com/act_runner/$ACT_RUNNER_VERSION/act_runner-$ACT_RUNNER_VERSION-linux-amd64" \
        "$ACT_RUNNER_SHA256" /usr/local/bin/act_runner
}

download() {
    local url="$1" sha="$2" dest="$3"
    local file="$install_tmp/$(basename "$dest")"
    curl -fsSL -o "$file" "$url"
    echo "$sha  $file" | sha256sum --check --quiet || fail "checksum mismatch for $url"
    install -m 0755 "$file" "$dest"
    echo "Installed $dest"
}

# lets the runner's systemd user service start at boot without a login
enable_linger() {
    loginctl enable-linger "$1"
}

fail() {
    echo "gitea-runner-deps.sh: $*" >&2
    exit 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
