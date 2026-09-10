-- Burst scene capture for Ninja Emaki (nnjema core).
--
-- One MAME run, dumps at fixed frame numbers. The dump matches the core's
-- IOCTL layout exactly (see cfg/mem.yaml ioctl order), which is a single
-- contiguous Z80 walk:
--   text code  0xd800  0x400   -> vcode
--   text attr  0xdc00  0x400   -> vattr
--   sprites    0xe000  0x200   -> oram
--   + 6 bytes state -> rest.bin (xlo,xhi,ylo,yhi,dispdisable,pad)
-- Writes /tmp/nnjema_burst_<frame>_dump.bin + _screen.png;
-- burst_capture.sh collates into ver/ninjemak/scenes/burst_<frame>/.

-- NOTE: reads at 0xd800-0xdfff through the CPU map return banked ROM
-- (videoram is write-only there), so use the memory shares instead
local vram   = manager.machine.memory.shares[":videoram"]
local oram   = manager.machine.memory.shares[":spriteram"]

-- dispdisable rides gfxbank writes (io 0x80 bit 4)
-- the tap handle must stay global or the GC silently removes it
gfxbank_reg = 0
local iosp = manager.machine.devices[":maincpu"].spaces["io"]
gfxbank_tap = iosp:install_write_tap(0x80, 0x80, "gfxbank_tap",
    function(offset, data, mask) gfxbank_reg = data & 0xff end)
local screen = nil
for _, scr in pairs(manager.machine.screens) do screen = scr; break end

local targets = { 300, 600, 900, 1200, 1500, 1800, 2100, 2400,
                  2700, 3000, 3300, 3600, 3900, 4200, 4500 }
local idx = 1

local function capture(frame)
    -- sprites are buffered: grab the live RAM now, everything else next frame
    pending_oram = {}
    for i = 0, 0x1ff do pending_oram[i] = oram:read_u8(i) end
    pending_frame = frame
    print(string.format("[burst] frame=%05d oram latched", frame))
end

local function finish_capture()
    local prefix = string.format("/tmp/nnjema_burst_%05d", pending_frame)
    local f = io.open(prefix .. "_dump.bin", "wb")
    for i = 0, 0x7ff do
        f:write(string.char(vram:read_u8(i)))
    end
    for i = 0, 0x1ff do
        f:write(string.char(pending_oram[i]))
    end
    -- scroll state: same vram params the NB1414M4 latches on blit
    f:write(string.char(vram:read_u8(0x0d), vram:read_u8(0x0e),
                        vram:read_u8(0x0b), vram:read_u8(0x0c),
                        (gfxbank_reg >> 4) & 1, 0))
    f:close()
    if screen ~= nil then screen:snapshot(prefix .. "_screen.png") end
    print(string.format("[burst] frame=%05d captured", pending_frame))
end

pending_oram = nil
pending_frame = nil

local function on_frame_done()
    if pending_oram ~= nil then
        finish_capture()
        pending_oram = nil
    end
    if idx > #targets then return end
    local cur = screen ~= nil and screen:frame_number() or 0
    while idx <= #targets and cur >= targets[idx] do
        capture(targets[idx])
        idx = idx + 1
    end
    if idx > #targets and pending_oram == nil then
        print("[burst] all targets captured, exiting")
        local ok = pcall(function() manager.machine:exit() end)
        if not ok then pcall(function() emu.exit() end) end
    end
end

emu.register_frame_done(on_frame_done, "nnjema_burst")
print(string.format(">> nnjema burst capture armed: %d targets <<", #targets))
