-- Burst scene capture for Cosmo Police Galivan (nnjema core).
--
-- One MAME run, dumps at fixed frame numbers. The dump matches the core's
-- IOCTL layout exactly (see cfg/mem.yaml ioctl order), which is a single
-- contiguous Z80 walk:
--   text code  0xd800  0x400   -> vcode
--   text attr  0xdc00  0x400   -> vattr
--   sprites    0xe000  0x100 (+0x100 zero pad)
--   + 4 bytes scroll state -> rest.bin (raw ports 0x41-0x44)   -> oram
-- Writes /tmp/nnjema_gburst_<frame>_dump.bin + _screen.png;
-- burst_capture.sh collates into ver/galivan/scenes/burst_<frame>/.

-- NOTE: reads at 0xd800-0xdfff through the CPU map return banked ROM
-- (videoram is write-only there), so use the memory shares instead
local vram   = manager.machine.memory.shares[":videoram"]
local oram   = manager.machine.memory.shares[":spriteram"]

-- scroll/layer latches live in the CPU, shadow them from the io writes
-- (handles must stay global or the GC silently removes the tap)
scroll_regs = { [0x41]=0, [0x42]=0, [0x43]=0, [0x44]=0 }
local iosp = manager.machine.devices[":maincpu"].spaces["io"]
scroll_tap = iosp:install_write_tap(0x41, 0x44, "scroll_tap",
    function(offset, data, mask)
        scroll_regs[offset & 0xff] = data & 0xff
    end)
local screen = nil
for _, scr in pairs(manager.machine.screens) do screen = scr; break end

local targets = { 300, 600, 900, 1200, 1500, 1800, 2100, 2400,
                  2700, 3000, 3300, 3600, 3900, 4200, 4500 }
local idx = 1

local function capture(frame)
    local prefix = string.format("/tmp/nnjema_gburst_%05d", frame)
    local f = io.open(prefix .. "_dump.bin", "wb")
    for i = 0, 0x7ff do
        f:write(string.char(vram:read_u8(i)))
    end
    for i = 0, 0xff do
        f:write(string.char(oram:read_u8(i)))
    end
    f:write(string.rep("\0", 0x100))
    f:write(string.char(scroll_regs[0x41], scroll_regs[0x42],
                        scroll_regs[0x43], scroll_regs[0x44]))
    f:close()
    pending_shot = prefix .. "_screen.png"
    print(string.format("[burst] frame=%05d captured", frame))
end

pending_shot = nil

local function on_frame_done()
    if pending_shot ~= nil then
        -- sprites are drawn from the buffered RAM: shoot one frame after the dump
        if screen ~= nil then screen:snapshot(pending_shot) end
        pending_shot = nil
    end
    if idx > #targets then return end
    local cur = screen ~= nil and screen:frame_number() or 0
    while idx <= #targets and cur >= targets[idx] do
        capture(targets[idx])
        idx = idx + 1
    end
    if idx > #targets and pending_shot == nil then
        print("[burst] all targets captured, exiting")
        local ok = pcall(function() manager.machine:exit() end)
        if not ok then pcall(function() emu.exit() end) end
    end
end

emu.register_frame_done(on_frame_done, "nnjema_gburst")
print(string.format(">> nnjema burst capture armed: %d targets <<", #targets))
