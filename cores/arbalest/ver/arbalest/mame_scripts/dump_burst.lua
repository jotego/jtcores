-- arbalest 15-scene burst capture for FPGA scene-replay grading.
-- Fires at 15 frame targets (300 apart) in ONE MAME run. Each scene gets a
-- dump.bin in the byte layout cores/arbalest/ver/game/dump2bin.sh expects
-- (tlv ++ pal ++ yram ++ dma), a seta_cfg.hex (X1-001 ctrl low bytes), and a
-- screen.png (MAME snapshot). Mirror of dump_scene.lua, looped over targets.
--   tlv  16384 B  X1-012 VRAM     @ 0x900000  (16-bit -> byte-swap)
--   pal   1024 B  palette         @ 0x700000  (16-bit -> byte-swap)
--   yram  1024 B  X1-001 Y/intRAM @ 0xd00000  (8-bit raw)
--   dma  16384 B  X1-001 spr-code @ 0xe00000  (16-bit -> byte-swap)
--
-- Run (from repo root):
--   /Users/andreabogazzi/Emus/mame0276-arm64/mame -rompath ~/.mame/roms-local \
--      arbalest -autoboot_script cores/arbalest/ver/arbalest/mame_scripts/dump_burst.lua \
--      -snapshot_directory /tmp/arb_burst_snap -nothrottle -video none -seconds_to_run 80
local targets = {300,600,900,1200,1500,1800,2100,2400,2700,3000,3300,3600,3900,4200,4500}
local idx = 1

local mem    = manager.machine.devices[":maincpu"].spaces["program"]
local screen = nil
for _, scr in pairs(manager.machine.screens) do screen = scr; break end

-- 8-bit region: raw ascending bytes.
local function dump(f, start, len)
    for a = start, start + len - 1 do f:write(string.char(mem:read_u8(a))) end
end
-- 16-bit region: byte-SWAP each word (MAME 68000 big-endian -> FPGA SIMFILE little).
local function dump16(f, start, len)
    for a = start, start + len - 1, 2 do
        f:write(string.char(mem:read_u8(a + 1)))   -- low byte first
        f:write(string.char(mem:read_u8(a)))        -- then high byte
    end
end

local function capture(frame)
    local dir = string.format("/tmp/arbalest_burst_%05d", frame)
    os.execute("mkdir -p '" .. dir .. "'")
    local f = io.open(dir .. "/dump.bin", "wb")
    dump16(f, 0x900000, 0x4000)   -- tlv
    dump16(f, 0x700000, 0x0400)   -- pal
    dump  (f, 0xd00000, 0x0400)   -- yram
    dump16(f, 0xe00000, 0x4000)   -- dma
    f:close()
    local c = io.open(dir .. "/seta_cfg.hex", "w")
    c:write(string.format("%02X\n%02X\n%02X\n%02X\n",
        mem:read_u8(0xd00601), mem:read_u8(0xd00603),
        mem:read_u8(0xd00605), mem:read_u8(0xd00607)))
    c:close()
    manager.machine.video:snapshot()  -- -> snapshot_directory/<game>/NNNN.png in call order
    print(string.format("[burst] frame=%d captured dump.bin + snapshot", frame))
end

-- keep the handle in a global so it is not GC'd mid-run
_G.arb_burst_h = emu.register_frame_done(function()
    if idx > #targets then return end
    local cur = screen and screen:frame_number() or 0
    if cur >= targets[idx] then
        capture(targets[idx])
        idx = idx + 1
        if idx > #targets then
            local ok = pcall(function() manager.machine:exit() end)
            if not ok then pcall(function() emu.exit() end) end
        end
    end
end, "arb_burst")
print(">> arbalest 15-scene burst armed (" .. #targets .. " targets) <<")
