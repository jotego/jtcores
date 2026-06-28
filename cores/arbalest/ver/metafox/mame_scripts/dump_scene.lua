-- metafox scene capture for FPGA scene-replay grading.
-- At the target frame it writes /tmp/metafox_scene.bin in the byte layout that
-- cores/arbalest/ver/game/dump2bin.sh expects (tlv ++ pal ++ yram ++ dma):
--   0x0000  tlv  16384 B  X1-012 VRAM      @ 0x900000
--   0x4000  pal   1024 B  palette          @ 0x700000
--   0x4400  yram  1024 B  X1-001 Y/intRAM  @ 0xd00000
--   0x4800  dma   8192 B  X1-001 spr-code  @ 0xe00000  (low 8 KB)
-- and a screenshot via MAME's snapshot, then exits.
--
-- Run (from repo root):
--   /Users/andreabogazzi/Emus/mame0276-arm64/mame -rompath ~/.mame/roms-local \
--      metafox -autoboot_script cores/arbalest/ver/metafox/mame_scripts/dump_scene.lua \
--      -snapshot_directory /tmp/metasnap -nothrottle -video bgfx -window -seconds_to_run 12
local TARGET = 520   -- ~META FOX title screen

local mem    = manager.machine.devices[":maincpu"].spaces["program"]
local screen = nil
for _, scr in pairs(manager.machine.screens) do screen = scr; break end
local done = false

-- 8-bit region: raw bytes in ascending address order.
local function dump(f, start, len)
    for a = start, start + len - 1 do f:write(string.char(mem:read_u8(a))) end
end

-- 16-bit region: byte-SWAP each word. MAME memory is 68000 big-endian (high byte
-- at the even address); the FPGA BRAM SIMFILE load expects FPGA-native
-- little-endian word order (low byte first), the same order cal50's self-captured
-- scenes use. Without this the X1-012 tile codes read byte-swapped -> garbage.
local function dump16(f, start, len)
    for a = start, start + len - 1, 2 do
        f:write(string.char(mem:read_u8(a + 1)))   -- low byte first
        f:write(string.char(mem:read_u8(a)))        -- then high byte
    end
end

local function on_frame_done()
    if done then return end
    local cur = screen and screen:frame_number() or 0
    if cur < TARGET then return end
    done = true
    local f = io.open("/tmp/metafox_scene.bin", "wb")
    dump16(f, 0x900000, 0x4000)   -- tlv  (X1-012 VRAM)        16-bit -> swap
    dump16(f, 0x700000, 0x0400)   -- pal                       16-bit -> swap
    dump  (f, 0xd00000, 0x0400)   -- yram (X1-001 internal / Y) 8-bit  -> raw
    dump16(f, 0xe00000, 0x4000)   -- dma  (X1-001 sprite code, FULL 16 KB) 16-bit -> swap
    f:close()
    -- X1-001 sprite control cfg[0..3] (low byte of each 16-bit reg @ 0xd00600..607).
    -- NOMAIN scene replay loads these into jtkiwi_gfx via $readmemh("seta_cfg.hex").
    local c = io.open("/tmp/seta_cfg.hex","w")
    c:write(string.format("%02X\n%02X\n%02X\n%02X\n",
        mem:read_u8(0xd00601), mem:read_u8(0xd00603),
        mem:read_u8(0xd00605), mem:read_u8(0xd00607)))
    c:close()
    manager.machine.video:snapshot()
    print(string.format("[scene] frame=%d captured dump.bin + snapshot", cur))
    local ok = pcall(function() manager.machine:exit() end)
    if not ok then pcall(function() emu.exit() end) end
end

emu.register_frame_done(on_frame_done, "metafox_scene")
print(">> metafox scene capture armed (target frame "..TARGET..") <<")
