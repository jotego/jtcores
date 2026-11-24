#!/usr/bin/env bash
# Tests jtbin2mr with stub sshpass and ping. No MiSTer or SD card is accessed.
set -euo pipefail

main() {
    setup
    test_default_copy
    test_new_flags
    test_hash_pattern
    test_sd_card
    test_refused_folders
    test_missing_folder
    test_offline
    test_parallel
    echo PASS
}

setup() {
    script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
    jtbin2mr=$script_dir/jtbin2mr
    work=$(mktemp -d)
    trap 'rm -rf -- "$work"' EXIT
    make_stubs
    make_release
    mkdir -p "$work/sd"
    sd=$work/no-sd
    # USER points to no real SD card, in case JTBIN2MR_SD were ignored
    base_env=(
        "PATH=$work/stub:$PATH" "JTROOT=$work/root" "JTBIN=$work/jtbin" "JTUTIL=$work/jtutil"
        "MISTERPASSWD=stub" "USER=jtbin2mr-test-nouser"
    )
}

# sshpass logs the remote command, or the files that scp would copy
make_stubs() {
    mkdir -p "$work/stub" "$work/root" "$work/jtutil"
    cat > "$work/stub/sshpass" <<'EOF'
#!/usr/bin/env bash
shift 2
if [ "$1" = ssh ]; then
    echo "ssh ${*: -2:1} ${*: -1}" >> "$STUB_LOG"
elif [ "$1" = scp ]; then
    for arg in "$@"; do
        if [ -d "$arg" ]; then
            (cd "$arg" && find . -type f | sed "s|^\.|scp $arg|") >> "$STUB_LOG"
        fi
    done
    echo "scp-dest ${*: -1}" >> "$STUB_LOG"
fi
EOF
    cat > "$work/stub/ping" <<'EOF'
#!/usr/bin/env bash
echo "ping ${*: -1}" >> "$STUB_LOG"
[ "${*: -1}" != offline ]
EOF
    chmod +x "$work/stub/sshpass" "$work/stub/ping"
}

make_release() {
    mkdir -p "$work/jtbin/mister" "$work/jtbin/mra" "$work/jtbin/cab"
    touch "$work/jtbin/mister/jt1942.rbf" "$work/jtbin/mra/1942.mra" "$work/jtbin/cab/1942.cab"
}

run() {
    local log=$1
    shift
    : > "$log"
    (cd "$work" && env "${base_env[@]}" "JTBIN2MR_SD=$sd" "STUB_LOG=$log" bash "$jtbin2mr" "$@")
}

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

expect() {
    grep -Eq -- "$2" "$1" || fail "$3: missing /$2/ in $1"
}

reject() {
    if grep -Eq -- "$2" "$1"; then fail "$3: unexpected /$2/ in $1"; fi
}

test_default_copy() {
    local log=$work/default.log
    run "$log" -g -m host0 > /dev/null
    expect "$log" '^ping host0$' default
    expect "$log" '^ssh host0 rm -rf /media/fat/_JTBIN$' default
    expect "$log" '^ssh host0 rm -rf /media/fat/config/nvram/\*\.nvm$' default
    expect "$log" '^scp .*/_JTBIN/cores/jt1942\.rbf$' default
    expect "$log" '^scp .*/_JTBIN/1942\.mra$' default
    expect "$log" '^scp-dest root@host0:/media/fat$' default
    reject "$log" 'for d in' default
}

test_new_flags() {
    local log=$work/flags.log
    sd=$work/sd
    run "$log" -g --skip-sd --folder _1234abc --delete-hash-folders -m host1 > /dev/null
    [ -z "$(ls -A "$work/sd")" ] || fail "--skip-sd wrote to the SD card"
    expect "$log" '^ping host1$' flags
    expect "$log" '^ssh host1 for d in /media/fat/_\*; do case' flags
    expect "$log" '^ssh host1 rm -rf /media/fat/_1234abc$' flags
    reject "$log" '_JTBIN' flags
    expect "$log" '^scp .*/_1234abc/cab/1942\.cab$' flags
    expect "$log" '^scp .*/_1234abc/cores/jt1942\.rbf$' flags
    expect "$log" '^scp .*/_1234abc/1942\.mra$' flags
    [ "$(grep -n 'for d in' "$log" | cut -d: -f1)" -lt "$(grep -n '^scp' "$log" | head -1 | cut -d: -f1)" ] ||
        fail "hash folders removed after the copy"
}

# Runs the logged remote command over a fake /media/fat
test_hash_pattern() {
    local fat=$work/fat cmd shell
    local keep=(_Arcade _Console _Computer _Other _Utility _JTBIN _ABC1234 _1234abcd _1234ab _1234abc-dirtyx _abcdefg _1234abc.bak)
    local gone=(_1234abc _1234abc-dirty _0000000)
    mkdir -p "${keep[@]/#/$fat/}" "${gone[@]/#/$fat/}" "$fat/games"
    touch "$fat/_7654321"
    cmd=$(sed -n 's/^ssh host1 \(for d in .*\)$/\1/p' "$work/flags.log")
    shell=$(command -v busybox > /dev/null && echo "busybox sh" || echo sh)
    $shell -c "${cmd//\/media\/fat/$fat}" || fail "remote command failed under $shell"
    for d in "${keep[@]}" games _7654321; do [ -e "$fat/$d" ] || fail "hash pattern removed $d"; done
    for d in "${gone[@]}"; do [ ! -e "$fat/$d" ] || fail "hash pattern kept $d"; done
}

test_sd_card() {
    local log=$work/sd.log
    sd=$work/sd
    run "$log" -g --folder _sdtest -m host2 > /dev/null
    [ -e "$work/sd/_sdtest/cab/1942.cab" ] || fail "SD copy without cab/"
    [ -e "$work/sd/_sdtest/cores/jt1942.rbf" ] || fail "SD copy without the core"
    [ ! -s "$log" ] || fail "SD copy used the network"
}

test_refused_folders() {
    local log=$work/refused.log name
    for name in _Arcade _console _COMPUTER _Other _utility JTBIN _ "_a b" "_a/b" ../x "_a;b" "_\$x" ""; do
        if run "$log" -g --skip-sd --folder "$name" -m host3 > /dev/null 2>&1; then
            fail "accepted folder name '$name'"
        fi
        [ ! -s "$log" ] || fail "folder name '$name' reached the network"
    done
}

test_missing_folder() {
    local log=$work/missing.log out
    if out=$(run "$log" -g --skip-sd -m host4 --folder 2>&1); then fail "accepted --folder without a name"; fi
    [[ "$out" == *"--folder needs a folder name"* ]] || fail "no message for --folder without a name"
    [ ! -s "$log" ] || fail "--folder without a name reached the network"
}

test_offline() {
    local log=$work/offline.log
    if run "$log" -g --skip-sd -m offline > /dev/null; then fail "offline host exited 0"; fi
    expect "$log" '^ping offline$' offline
    reject "$log" '^(ssh|scp)' offline
}

test_parallel() {
    local k pids=()
    for k in 1 2 3; do
        run "$work/par$k.log" -g --skip-sd --folder _abcdef0 --delete-hash-folders -m "board$k" > /dev/null &
        pids+=($!)
    done
    for k in "${pids[@]}"; do wait "$k" || fail "parallel copy failed"; done
    for k in 1 2 3; do
        expect "$work/par$k.log" "^scp-dest root@board$k:/media/fat$" parallel
        expect "$work/par$k.log" '^scp .*/_abcdef0/cab/1942\.cab$' parallel
        reject "$work/par$k.log" "board[^$k]" parallel
    done
    [ "$(cat "$work"/par?.log | sed -n 's|^scp \(.*\)/_abcdef0/.*|\1|p' | sort -u | wc -l)" = 3 ] ||
        fail "parallel copies shared a temporary folder"
}

main "$@"
