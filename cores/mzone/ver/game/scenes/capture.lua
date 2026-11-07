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

-- These are write-only hardware latches, so retain their most recent writes.
-- Keep the returned tap objects alive until the capture is complete.
local read_saved_registers
local register_taps
local has_write_tap, write_tap = pcall(function() return memory.install_write_tap end)
if has_write_tap and write_tap then
    register_taps = {
        memory:install_write_tap(0x1000, 0x1000, "mzone_scrolly",
            function(_, data)
                registers.scrolly = data & 0xff
            end),
        memory:install_write_tap(0x1800, 0x1800, "mzone_scrollx",
            function(_, data)
                registers.scrollx = data & 0xff
            end),
        memory:install_write_tap(0x0005, 0x0005, "mzone_flip",
            function(_, data)
                registers.flip = data & 0x01
            end)
    }

else
    -- MAME 0.220 exposes the write-only scroll shares and the LS259 state.
    local manager_memory = machine.memory
    if type(manager_memory) == "function" then manager_memory = machine:memory() end
    local shares = manager_memory.shares
    local latch = emu.item(assert(machine.devices[":mainlatch"].items["0/m_q"]))
    read_saved_registers = function()
        registers.scrolly = shares[":scrolly"]:read_u8(0)
        registers.scrollx = shares[":scrollx"]:read_u8(0)
        registers.flip = (latch:read(0) >> 5) & 1
    end
end

local function region(address, size)
    local data = {}
    for offset = 0, size - 1 do
        data[offset + 1] = string.char(memory:read_u8(address + offset))
    end
    return table.concat(data)
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
    if read_saved_registers then read_saved_registers() end

    -- cfg/mem.yaml ioctl order, followed by cfg/mmr.yaml video registers.
    local path = output .. "/dump.bin"
    local file = assert(io.open(path .. ".tmp", "wb"))
    assert(file:write(
        region(0x2000, 0x400), region(0x2400, 0x400),
        region(0x2800, 0x400), region(0x2c00, 0x400),
        region(0x3000, 0x400), region(0x3800, 0x800),
        string.char(registers.scrolly, registers.scrollx, registers.flip, 0)))
    assert(file:close())
    assert(os.rename(path .. ".tmp", path))

    local marker_path = output .. "/.capture-complete"
    local marker = assert(io.open(marker_path, "w"))
    assert(marker:write(string.format("%d\n", frame)))
    assert(marker:close())

    if read_saved_registers then
        print("Video registers read from MAME scroll shares and saved LS259 latch")
    end
    print(string.format(
        "M-Zone scene captured at frame %d: scrolly=%02X, scrollx=%02X, flip=%02X",
        frame, registers.scrolly, registers.scrollx, registers.flip))
    machine:exit()
end)
