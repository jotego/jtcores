-- Burst scene capture for the Osman core (Data East Simple 156).
--
-- Fires a full video-state dump at 15 MAME frame numbers in one run, so we don't
-- relaunch MAME per scene. Each point writes under /tmp/osman_burst_<frame>/:
--   dump.bin    concatenation the FPGA scene replay will consume (order below)
--   screen.png  MAME's rendered frame, for grading with the scene-diff skill.
--
-- Regions (simpl156 CPU program space; the ARM is 32-bit but the video devices sit
-- on the low 16 bits — palette/spr/pf are effectively 16-bit, 2-byte spaced; the
-- palette 2-byte spacing was confirmed by read_u16(0x1a0000+i*2)=pen(i)). read_u8
-- walks ascending addresses = the CPU's native byte order; the FPGA SIMFILE loader
-- (built later with the NOMAIN scene-replay branch) must match this split + endian.
--
-- Run from the repo root:
--   ./mame osman -autoboot_script \
--       cores/osman/ver/osman/mame_scripts/dump_burst.lua \
--       -autoboot_delay 1 -nothrottle -video none -seconds_to_run 85
-- then collate with cores/osman/ver/osman/scenes/burst_capture.sh

local mem    = manager.machine.devices[":maincpu"].spaces["program"]
local screen = nil
for _, scr in pairs(manager.machine.screens) do screen = scr; break end

-- 15 targets, 300 frames apart (58 Hz -> ~5s .. ~77s): attract + intro moments.
local targets = { 300,600,900,1200,1500,1800,2100,2400,2700,3000,3300,3600,3900,4200,4500 }
local idx = 1

-- All video devices are 32-bit dword-mapped with the datum in the LOW 16 bits
-- (simpl156.cpp: palette read16 .umask32(0x0000ffff); pf/control _dword_ handlers).
-- The dump packs the low halfword of every dword as dense little-endian 16-bit,
-- cninja-style: the deco16ic control block comes FIRST so jtdeco16ic_mmr reads
-- rest.bin at SEEK=0, then the RAM images that rest2bin.sh cuts apart:
--   0x0000 0x0010 control | 0x0010 0x0800 pal   | 0x0810 0x1000 pf1
--   0x1810 0x1000 pf2     | 0x2810 0x1000 rs1   | 0x3810 0x1000 rs2
--   0x4810 0x1000 oram    | total 0x5810
local regions = {
    { start = 0x1c0000, dwords = 8    },   -- pf control regs (scroll / tile-size / flip / bank)
    { start = 0x1a0000, dwords = 1024 },   -- palette (1024 x xBGR-555)
    { start = 0x1d0000, dwords = 2048 },   -- pf1 name table (deco16ic)
    { start = 0x1d4000, dwords = 2048 },   -- pf2 name table
    { start = 0x1e0000, dwords = 2048 },   -- pf1 rowscroll
    { start = 0x1e4000, dwords = 2048 },   -- pf2 rowscroll
    { start = 0x190000, dwords = 2048 },   -- sprite RAM
}

local function capture(frame)
    local dir = string.format("/tmp/osman_burst_%05d", frame)
    os.execute("mkdir -p '" .. dir .. "'")
    local f = io.open(dir .. "/dump.bin", "wb")
    for _, r in ipairs(regions) do
        for i = 0, r.dwords - 1 do
            local v = mem:read_u16(r.start + i*4)      -- dword low halfword
            f:write(string.char(v % 256, math.floor(v/256) % 256))
        end
    end
    f:close()
    if screen ~= nil then screen:snapshot(dir .. "/screen.png") end
    print(string.format("[burst] frame=%05d captured -> %s", frame, dir))
end

emu.register_frame_done(function()
    if idx > #targets then return end
    local cur = screen ~= nil and screen:frame_number() or 0
    while idx <= #targets and cur >= targets[idx] do
        capture(targets[idx]); idx = idx + 1
    end
    if idx > #targets then
        print("[burst] all targets captured, exiting")
        manager.machine:exit()
    end
end)
