#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 19-10-2026

set -euo pipefail
roundu_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
roundu_core="$roundu_repo/cores/roundu"
roundu_set="$roundu_core/ver/roundup5"
roundu_work="$roundu_set/scratch/capture"
roundu_output="$roundu_set/scenes"
roundu_mame=${MAME_BINARY:-/Users/andreabogazzi/Emus/mame0276-arm64/mame}
roundu_rompath=${MAME_ROMPATH:-$HOME/.mame/roms-local}
roundu_frames=()
roundu_replace=0
roundu_prepare=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --frames)
            shift
            while [ "$#" -gt 0 ] && [[ "$1" != --* ]]; do
                [[ "$1" =~ ^[0-9]+$ ]] && (( 10#$1 > 0 )) || { echo 'Frames must be positive integers' >&2; exit 2; }
                roundu_frames+=("$((10#$1))"); shift
            done
            ;;
        --output) roundu_output=${2:?}; shift 2 ;;
        --replace) roundu_replace=1; shift ;;
        --prepare-only) roundu_prepare=1; shift ;;
        *) echo 'Usage: capture-video.sh [--frames 300 600 ...] [--output folder] [--replace] [--prepare-only]' >&2; exit 2 ;;
    esac
done
if [ "${#roundu_frames[@]}" -eq 0 ]; then
    for ((roundu_frame=300;roundu_frame<=6000;roundu_frame+=300)); do roundu_frames+=("$roundu_frame"); done
fi
mkdir -p "$roundu_work" "$roundu_output"
roundu_output=$(cd -- "$roundu_output" && pwd -P)
export JTROOT="$roundu_repo" JTFRAME="$roundu_repo/modules/jtframe"
export CORES="$roundu_repo/cores" MODULES="$roundu_repo/modules" JTBIN="$roundu_repo/release"
roundu_layout=$(awk '/^- name:/ {name=$3} /^  size:/ {print name,$2}' "$roundu_core/cfg/mmr.yaml")
[ "$roundu_layout" = "$(printf 'crtc 64\nmain 32\nroad 4\nobject 512')" ] || { echo 'Review the Round Up 5 MMR dump layout before capturing' >&2; exit 1; }
"$JTFRAME/bin/jtframemac" mmr roundu > "$roundu_work/mmr-generation.log" 2>&1
if [ "$roundu_prepare" = 1 ]; then echo 'Ready: 13 video blocks, 309850 dump bytes and 612 MMR bytes'; exit 0; fi
[ -x "$roundu_mame" ] || { echo 'Select your MAME 0.282 executable with MAME_BINARY' >&2; exit 1; }
roundu_version=$("$roundu_mame" -help)
roundu_version=${roundu_version%%$'\n'*}
case "$roundu_version" in "MAME v0.282 "*) ;; *) echo "Expected MAME 0.282; got $roundu_version" >&2; exit 1 ;; esac
roundu_archive="$roundu_rompath/roundup5.7z"
if [ ! -f "$roundu_archive" ]; then roundu_archive="$roundu_rompath/roundup5.zip"; fi
[ -f "$roundu_archive" ] || { echo 'Round Up 5 archive not found in MAME_ROMPATH' >&2; exit 1; }
cat > "$roundu_work/capture.lua" <<'LUA'
-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Date: 19-10-2026

local m=manager.machine
local root=m.devices[":"]
local screen=m.screens[":screen"]
local mem=m.devices[":maincpu"].spaces.program
local sub=m.devices[":sub"].spaces.program
local out=assert(os.getenv("ROUNDU_CAPTURE"))
local testmode=os.getenv("ROUNDU_TEST")=="1"
local play=os.getenv("ROUNDU_PLAY")=="1"
local drive=os.getenv("ROUNDU_DRIVE")=="1"
local startfield=nil
local accelerator=nil
local target=tonumber(os.getenv("ROUNDU_CAPTURE_FRAME") or "600")
local gfx=emu.item(assert(root.items["0/m_tx_gfxram"]))
local bg=emu.item(assert(root.items["0/m_bg_gfxram"]))
local crtc,index,control={},0,0
local taps={}
local frozen=nil
for i=0,63 do crtc[i]=0 end
for portname,port in pairs(m.ioport.ports) do
    for name,field in pairs(port.fields) do
        if portname==":IN0" and field.mask==0x20 then startfield=field end
        if portname==":IN0" and field.mask==0x01 then accelerator=field end
        if name=="Hardware Test Mode" then field.user_value=testmode and 0 or 0x8000 end
        if name=="Service Mode" or name=="Test Mode" then field.user_value=0 end
    end
end
taps[#taps+1]=mem:install_write_tap(0xc000,0xc003,"crtc_shadow",function(a,d,mask)
    if frozen then return a==0xc000 and index or crtc[index] end
    if (mask&0xff)~=0 then
        if a==0xc000 then index=d&0x3f else crtc[index]=d&0xff end
    end
end)
taps[#taps+1]=mem:install_write_tap(0xe000,0xe001,"control_shadow",function(a,d,mask)
    if frozen then return control end
    control=(control&(~mask))|(d&mask)
end)
local function read_state()
    local blocks={}
    local b={}
    for a=0x8000,0xbffe,2 do b[#b+1]=string.pack("<I2",mem:read_u16(a)) end
    blocks[1]=table.concat(b)
    b={}
    for i=0,0x1ffff do b[#b+1]=string.char(gfx:read(i)) end
    blocks[2]=table.concat(b)
    b={}
    for i=0,1023 do
        local hi=mem:read_u8(0xf000+i*4)
        local lo=mem:read_u8(0xf002+i*4)
        b[#b+1]=string.char(lo,hi)
    end
    blocks[3]=table.concat(b)
    b={}
    for i=0,63 do b[#b+1]=string.char(crtc[i]) end
    blocks[4]=table.concat(b)
    b={}
    for i=0,0x1ffff do b[#b+1]=string.char(bg:read(i)) end
    blocks[5]=table.concat(b)
    for n,r in ipairs({{0x90000,0x4000},{0x9a000,0x200},{0xa0000,0x1000},{0xb0000,0x1000},{0xc0000,0x1000},{0xd0000,2},{0xe0000,2}}) do
        b={}
        for a=r[1],r[1]+r[2]-2,2 do b[#b+1]=string.pack("<I2",sub:read_u16(a)) end
        blocks[5+n]=table.concat(b)
    end
    b={string.pack("<I2",control)}
    for _,name in ipairs({"vregs","bg_scrollx","bg_scrolly"}) do
        local share=assert(m.memory.shares[":"..name])
        local size=name=="vregs" and 16 or 2
        for a=0,size-2,2 do b[#b+1]=string.pack("<I2",share:read_u16(a)) end
    end
    blocks[13]=table.concat(b)
    return blocks
end
local function hold(space,lo,hi,name,reader)
    taps[#taps+1]=space:install_write_tap(lo,hi,name,function(a) return reader(a) end)
end
roundu_capture_notifier=emu.add_machine_frame_notifier(function()
    local frame=screen:frame_number()
    if play and frame==700 then
        assert(startfield,"Start input not found")
        startfield:set_value(1)
        print("VIDEO_INPUT frame=700 start=1")
    elseif play and frame==710 then
        startfield:set_value(0)
        print("VIDEO_INPUT frame=710 start=0")
    end
    if drive and frame==800 then
        assert(accelerator,"Accelerator input not found")
        accelerator:set_value(1)
        print("VIDEO_INPUT frame=800 accelerator=1")
    end
    if not frozen and frame>=target then
        assert(frame==target,"Missed capture frame")
        frozen=read_state()
        local f=assert(io.open(out.."/dump.bin","wb"))
        local size=0
        for _,block in ipairs(frozen) do f:write(block);size=size+#block end
        f:close()
        assert(size==309850,"Wrong video dump size")
        local mmr=frozen[4]..frozen[13]..string.rep("\0",10)..frozen[11]..frozen[12]..frozen[7]
        assert(#mmr==612,"Wrong MMR size")
        f=assert(io.open(out.."/mmr.bin","wb"))
        f:write(mmr)
        f:close()
        hold(mem,0x8000,0xbfff,"hold_text",function(a) return mem:read_u16(a) end)
        hold(mem,0xf000,0xffff,"hold_palette",function(a) return mem:read_u16(a) end)
        hold(mem,0x30000,0x3ffff,"hold_graphics",function(a) return mem:read_u16(a) end)
        hold(mem,0xe000,0xe001,"hold_control",function() return control end)
        hold(mem,0xc000,0xc003,"hold_crtc",function(a) return a==0xc000 and index or crtc[index] end)
        for _,r in ipairs({{0xd400,0xd40f,"vregs"},{0xd800,0xd801,"bg_scrollx"},{0xdc00,0xdc01,"bg_scrolly"}}) do
            local share=assert(m.memory.shares[":"..r[3]])
            local base=r[1]
            hold(mem,r[1],r[2],"hold_"..r[3],function(a) return share:read_u16(a-base) end)
        end
        for _,r in ipairs({{0x90000,0x93fff},{0x9a000,0x9a1ff},{0xa0000,0xa0fff},{0xb0000,0xb0fff},{0xc0000,0xc0fff},{0xd0000,0xd0001},{0xe0000,0xe0001}}) do
            hold(sub,r[1],r[2],"hold_sub_"..r[1],function(a) return sub:read_u16(a) end)
        end
        print("VIDEO_DUMP_OK frame="..frame.." bytes="..size)
    elseif frozen then
        assert(frame==target+1,"Unexpected reference boundary")
        local current=read_state()
        for i=1,#frozen do assert(current[i]==frozen[i],"Held text state changed") end
        assert(not screen:snapshot(out.."/screen.png"),"Snapshot failed")
        print("VIDEO_REFERENCE_OK frame="..frame.." video_state_held=1 testmode="..tostring(testmode))
        m:exit()
    end
end)
LUA
{
    printf '%s\n%s\n' "$roundu_version" "$roundu_mame"
    shasum -a 256 "$roundu_mame" "$roundu_archive" "$roundu_core/cfg/mem.yaml" "$roundu_core/cfg/mmr.yaml" "$roundu_work/capture.lua"
    printf 'Inputs: Start 1 at 700..709; Accelerator held from 800. State held F to F+1.\n'
} > "$roundu_work/capture.log"
: > "$roundu_work/captures.sha256"
for roundu_frame in $(printf '%s\n' "${roundu_frames[@]}" | sort -nu); do
    roundu_target="$roundu_output/$roundu_frame"
    if [ -e "$roundu_target" ]; then
        [ "$roundu_replace" = 1 ] || { echo "$roundu_target exists; use --replace to regenerate" >&2; exit 1; }
        rm -rf -- "$roundu_target"
    fi
    mkdir -p "$roundu_target"
    roundu_settings="$roundu_work/settings"
    rm -rf -- "$roundu_settings"
    mkdir -p "$roundu_settings"
    export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
    export ROUNDU_CAPTURE="$roundu_target" ROUNDU_CAPTURE_FRAME="$roundu_frame"
    export ROUNDU_TEST=0 ROUNDU_PLAY=1 ROUNDU_DRIVE=1
    printf 'FRAME %s\n' "$roundu_frame" >> "$roundu_work/capture.log"
    "$roundu_mame" roundup5 -rompath "$roundu_rompath" -noreadconfig \
        -inipath "$roundu_settings" -homepath "$roundu_settings" -cfg_directory "$roundu_settings" \
        -nvram_directory "$roundu_settings" -snapshot_directory "$roundu_settings" \
        -video soft -window -sound none -nothrottle -skip_gameinfo -snapview native -nosnapbilinear \
        -autoboot_script "$roundu_work/capture.lua" -autoboot_delay 0 \
        -seconds_to_run "$((roundu_frame/57+5))" >> "$roundu_work/capture.log" 2>&1
    [ "$(wc -c < "$roundu_target/dump.bin" | tr -d ' ')" = 309850 ]
    [ "$(wc -c < "$roundu_target/mmr.bin" | tr -d ' ')" = 612 ]
    file -b "$roundu_target/screen.png" | grep -q '320 x 240'
    grep -q "VIDEO_REFERENCE_OK frame=$((roundu_frame+1)) video_state_held=1" "$roundu_work/capture.log"
    shasum -a 256 "$roundu_target/dump.bin" "$roundu_target/mmr.bin" "$roundu_target/screen.png" >> "$roundu_work/captures.sha256"
    printf 'Captured %s\n' "$roundu_target"
done
rm -rf -- "$roundu_work/settings"
