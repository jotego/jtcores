#!/usr/bin/env bash
main() {
    local destination="$1" duration="${2:-30}" play="${3:-1}"
    mkdir "$destination" || return
    destination="$(realpath "$destination")"
    local mame_binary=/home/jtejada/mame/mame
    local rom_path=/nobackup/mame/current
    cp "$JTROOT/tasks/jt51-13/scripts/record-rastan.lua" "$destination/record-rastan.lua"
    local args=(rastan -rompath "$rom_path" -debug -debugger none -nothrottle
        -sound none -video none -skip_gameinfo -autoboot_delay 0
        -autoboot_script "$JTFRAME/mame/mamedbg.lua" -noreadconfig -nowriteconfig
        -seconds_to_run "$((duration+1))" -cfg_directory "$destination/cfg"
        -nvram_directory "$destination/nvram")
    printf '%q ' timeout 5m "$mame_binary" "${args[@]}" > "$destination/command.txt"
    printf '\nTRACE_SECONDS=%s\nTRACE_PLAY=%s\n' "$duration" "$play" >> "$destination/command.txt"
    sha256sum "$mame_binary" "$rom_path/rastan.zip" \
        "$destination/record-rastan.lua" \
        "$JTFRAME/mame/mamedbg.lua" > "$destination/input-sha256.txt"
    git -C /home/jtejada/mame rev-parse HEAD > "$destination/mame-source-commit.txt"
    git -C /home/jtejada/mame status --short > "$destination/mame-source-status.txt"
    TRACE_DIR="$destination" TRACE_SECONDS="$duration" TRACE_PLAY="$play" \
        MAMEDBG_SCRIPT="$destination/record-rastan.lua" \
        MAMEDBG_TIMEOUT=120 MAMEDBG_LOG="$destination/wrapper.log" \
        SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
        timeout 5m "$mame_binary" "${args[@]}" \
        > "$destination/stdout.log" 2> "$destination/stderr.log"
    local capture_status=$?
    printf '%s\n' "$capture_status" > "$destination/exit-status.txt"
    if ((capture_status != 0)); then return "$capture_status"; fi
    rg -q '^reason=emulated_time_limit$' "$destination/capture.txt" || return 1
    sha256sum "$destination/bus.csv" "$destination/registers.csv" > "$destination/output-sha256.txt"
}
main "$@"
