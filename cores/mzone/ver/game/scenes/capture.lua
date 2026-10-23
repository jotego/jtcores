-- SPDX-License-Identifier: GPL-3.0-or-later

-- Generic M-Zone scene capture. The per-scene file returns the target frame
-- and, when needed, input callbacks.

local machine = manager.machine
if type(machine) == "function" then
    machine = manager:machine()
end

local screen = machine.screens[":screen"]
local memory = machine.devices[":maincpu"].spaces["program"]
local output = assert(os.getenv("MZONE_SCENE_OUT"), "MZONE_SCENE_OUT is not set")
local config_path = assert(os.getenv("MZONE_SCENE_CONFIG"), "MZONE_SCENE_CONFIG is not set")
local scene = assert(loadfile(config_path))()

assert(type(scene) == "table", "scene configuration must return a table")
assert(type(scene.frame) == "number", "scene.frame must be a number")

local registers = {
    scrolly = 0,
    scrollx = 0,
    flip = 0
}
local register_writes = { scrolly = 0, scrollx = 0, flip = 0 }

-- These are write-only hardware latches, so retain their most recent writes.
-- Keep the returned tap objects alive until the capture is complete.
local register_taps = {
    memory:install_write_tap(0x1000, 0x1000, "mzone_scrolly",
        function(_, data)
            registers.scrolly = data & 0xff
            register_writes.scrolly = register_writes.scrolly + 1
        end),
    memory:install_write_tap(0x1800, 0x1800, "mzone_scrollx",
        function(_, data)
            registers.scrollx = data & 0xff
            register_writes.scrollx = register_writes.scrollx + 1
        end),
    memory:install_write_tap(0x0005, 0x0005, "mzone_flip",
        function(_, data)
            registers.flip = data & 0x01
            register_writes.flip = register_writes.flip + 1
        end)
}

local function save_region(name, address, size)
    local path = output .. "/" .. name
    local temporary = path .. ".tmp"
    local file = assert(io.open(temporary, "wb"))
    local data = {}

    for offset = 0, size - 1 do
        data[offset + 1] = string.char(memory:read_u8(address + offset))
    end

    assert(file:write(table.concat(data)))
    assert(file:close())
    assert(os.rename(temporary, path))
end

if scene.initialize then
    scene.initialize(machine)
end

local captured = false
emu.register_frame(function()
    local _ = register_taps
    local frame = screen:frame_number()

    if scene.update then
        scene.update(machine, frame)
    end

    if captured or frame < scene.frame then
        return
    end
    captured = true

    save_region("vram0.bin",  0x2000, 0x400)
    save_region("vram1.bin",  0x2400, 0x400)
    save_region("cram0.bin",  0x2800, 0x400)
    save_region("cram1.bin",  0x2c00, 0x400)
    save_region("obj.bin",    0x3000, 0x400)
    save_region("shared.bin", 0x3800, 0x800)

    local regs_path = output .. "/regs.hex"
    local regs_tmp = regs_path .. ".tmp"
    local regs = assert(io.open(regs_tmp, "w"))
    assert(regs:write(string.format("%02X\n%02X\n%02X\n",
        registers.scrolly, registers.scrollx, registers.flip)))
    assert(regs:close())
    assert(os.rename(regs_tmp, regs_path))

    local marker_path = output .. "/.capture-complete"
    local marker = assert(io.open(marker_path, "w"))
    assert(marker:write(string.format("%d\n", frame)))
    assert(marker:close())

    print(string.format(
        "M-Zone scene captured at frame %d: scrolly=%02X (%d writes), scrollx=%02X (%d writes), flip=%02X (%d writes)",
        frame, registers.scrolly, register_writes.scrolly,
        registers.scrollx, register_writes.scrollx,
        registers.flip, register_writes.flip))
    machine:exit()
end)
