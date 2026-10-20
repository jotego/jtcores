#!/bin/bash
set -euo pipefail

main() {
    [[ $# == 1 && ( $1 == yamaha || $1 == yamaha104 || $1 == original ) ]] || {
        echo "Usage: $0 yamaha104|yamaha|original (run as root on Chameleon96)" >&2
        exit 2
    }
    [[ $(id -u) == 0 && $(uname -m) == armv7l ]]
    [[ $(tr -d '\0' < /proc/device-tree/model) == 'NovTech CV96' ]]
    ip -4 address show usb0 | grep -q '192.168.96.96/'
    awk '$1=="h2f_user0_clk" && $4==100000000 {ok=1} END {exit !ok}' \
        /sys/kernel/debug/clk/clk_summary
    local clock_enable
    clock_enable=$(/sbin/devmem 0xffd04060 32)
    (( (clock_enable & 512) != 0 ))
    exec 9>/var/lock/c96-capture.lock
    flock -n 9 || { echo "A capture command or FPGA load is running" >&2; exit 1; }
    local image="c96-$1" overlay=/sys/kernel/config/device-tree/overlays/c96
    [[ -s /lib/firmware/$image.rbf && -s /lib/firmware/$image.dtbo ]]
    [[ -d /sys/kernel/config/device-tree/overlays ]]
    for entry in /sys/kernel/config/device-tree/overlays/*; do
        [[ ! -e $entry || $entry == "$overlay" ]] || {
            echo "An unrelated overlay is active: $entry" >&2; exit 1;
        }
    done
    local watchdog="c96-recovery-$$"
    systemd-run --unit="$watchdog" --on-active=120 /sbin/reboot
    echo "Recovery reboot scheduled in 120 seconds if loading fails."
    quiesce_fabric
    /sbin/devmem 0xff706010 32 0
    if [[ -d $overlay ]]; then rmdir "$overlay"; fi
    mkdir "$overlay"
    # Use path, not `cat file > dtbo`: the old kernel can request firmware
    # during cat's exit after its filesystem context is gone, causing an oops.
    printf '%s\n' "$image.dtbo" > "$overlay/path"
    [[ $(cat "$overlay/status") == applied ]]
    [[ $(cat /sys/class/fpga_manager/fpga0/state) == operating ]]
    flock -u 9
    exec 9>&-
    if [[ $1 != original ]]; then "$(dirname "${BASH_SOURCE[0]}")/c96-capture" probe; fi
    systemctl stop "$watchdog.timer"
    echo "Loaded $image; recovery timer cancelled. SD boot files are unchanged."
}

quiesce_fabric() {
    systemctl stop chameleon96-xfce-init.service getty@tty1.service
    for entry in /sys/class/vtconsole/vtcon*; do
        if grep -q 'frame buffer' "$entry/name"; then echo 0 > "$entry/bind"; fi
    done
    unbind_driver ff211000.mmc0 sls_sdio
    unbind_driver ff201000.vip altvipfb
    unbind_driver ff220010.gpio altera_gpio
    for entry in /sys/bus/platform/devices/ff2*/driver; do
        [[ ! -e $entry ]] || { echo "Fabric driver still bound: $entry" >&2; exit 1; }
    done
}

unbind_driver() {
    local device=$1 driver=$2
    if [[ -L /sys/bus/platform/devices/$device/driver ]]; then
        [[ $(basename "$(readlink /sys/bus/platform/devices/$device/driver)") == "$driver" ]]
        printf '%s\n' "$device" > "/sys/bus/platform/drivers/$driver/unbind"
    fi
}

main "$@"
