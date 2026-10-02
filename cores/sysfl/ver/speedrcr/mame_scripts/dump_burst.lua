-- Burst scene capture for Speed Racer (Namco System FL, sysfl core).
--
-- One MAME run, video-state dump at fixed frame numbers. Each capture
-- writes /tmp/speedrcr_burst_<frame>_{pal,vram,scrctl,rozram,rozctl,oram,regs}.bin
-- + _screen.png; burst_capture.sh collates into ver/speedrcr/scenes/.
--
-- Regions (i960 little-endian, read_u8 walks native byte order):
--   pal     0x30400000  0x8000   (C116 window: R/G/B RAMs + regs)
--   vram    0x30800000  0x10000  (123 tilemaps)
--   scrctl  0x30a00000  0x40     (123 control)
--   rozram  0x30c00000  0x20000  (C169 tilemap + scanline records)
--   rozctl  0x30d00000  0x20     (C169 control)
--   oram    0x30e00000  0x20000  (C355 sprite tables)
--   regs    4 bytes: spritebank (write-only reg, captured via write tap)
--
-- Note: C355 buffers one frame: the screenshot at F shows the sprite list
-- as it stood at F-1 while tilemaps/roz render live. So oram (+sprbank) is
-- dumped at F-1 and every live region plus the screenshot at F.

local mem    = manager.machine.devices[":maincpu"].spaces["program"]
local screen = nil
for _, scr in pairs(manager.machine.screens) do screen = scr; break end

local targets = { 300, 600, 900, 1200, 1500, 3000, 3300, 3600,
                  3900, 4200, 4500, 4800, 5100, 5400, 5700, 6000,
                  6300, 6600, 6900, 7200 }
local idx = 1

-- write tap: keep handle global or GC silently kills it
sprbank_val = 0
sprbank_tap = mem:install_write_tap(0x30100000, 0x30100003, "sprbank",
    function(offset, data, mask) sprbank_val = data end)

local regions = {
    { name = "pal",    start = 0x30400000, len = 0x8000  },
    { name = "vram",   start = 0x30800000, len = 0x10000 },
    { name = "scrctl", start = 0x30a00000, len = 0x40    },
    { name = "rozram", start = 0x30c00000, len = 0x20000 },
    { name = "rozctl", start = 0x30d00000, len = 0x20    },
    { name = "oram",   start = 0x30e00000, len = 0x20000 },
}

local function dump_one(path, start, len)
    local f = io.open(path, "wb")
    for a = start, start + len - 1 do
        f:write(string.char(mem:read_u8(a)))
    end
    f:close()
end

local oram_done = false
local function capture_oram(frame)
    local prefix = string.format("/tmp/speedrcr_burst_%05d", frame)
    dump_one(prefix .. "_oram.bin", 0x30e00000, 0x20000)
    local f = io.open(prefix .. "_regs.bin", "wb")
    f:write(string.char( sprbank_val        & 0xff,
                        (sprbank_val >> 8)  & 0xff,
                        (sprbank_val >> 16) & 0xff,
                        (sprbank_val >> 24) & 0xff))
    f:close()
end

local function capture(frame)
    local prefix = string.format("/tmp/speedrcr_burst_%05d", frame)
    for _, r in ipairs(regions) do
        if r.name ~= "oram" then
            dump_one(prefix .. "_" .. r.name .. ".bin", r.start, r.len)
        end
    end
    if screen ~= nil then screen:snapshot(prefix .. "_screen.png") end
    print(string.format("[burst] frame=%05d captured, sprbank=%x", frame, sprbank_val))
end

local function on_frame_done()
    if idx > #targets then return end
    local cur = screen ~= nil and screen:frame_number() or 0
    if not oram_done and cur >= targets[idx]-1 then
        capture_oram(targets[idx])   -- the list the screenshot will display
        oram_done = true
    end
    while idx <= #targets and cur >= targets[idx] do
        capture(targets[idx])
        idx = idx + 1
        oram_done = false
        if idx <= #targets and cur >= targets[idx]-1 then
            capture_oram(targets[idx])
            oram_done = true
        end
    end
    if idx > #targets then
        print("[burst] all targets captured, exiting")
        local ok = pcall(function() manager.machine:exit() end)
        if not ok then pcall(function() emu.exit() end) end
    end
end

frame_notifier = emu.register_frame_done(on_frame_done, "speedrcr_burst")
print(string.format(">> speedrcr burst capture armed: %d targets <<", #targets))
