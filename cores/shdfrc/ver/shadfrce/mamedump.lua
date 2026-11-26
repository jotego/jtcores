-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Date: 25-11-2026

local lfs = require("lfs")
local machine = manager.machine
assert(machine.system.name == "shadfrce", "Expected shadfrce")
local screen = assert(machine.screens[":screen"])
local space = assert(machine.devices[":maincpu"].spaces.program)
local root = assert(machine.devices[":"])
local sprite = assert(machine.devices[":spvideoram"])
local buffered_index = assert(sprite.items["0/m_buffered"], "Missing buffered sprite RAM")
local buffered = emu.item(buffered_index)
local enabled = emu.item(assert(root.items["0/m_video_enable"]))
local flip_x = emu.item(assert(root.items["0/m_flip_screen_x"]))
local flip_y = emu.item(assert(root.items["0/m_flip_screen_y"]))
assert(buffered.size == 2 and buffered.count == 4096, "Sprite RAM size changed")

local blocks = {
    { target = "vram.bin", address = 0x100000, words = 8192 },
    { target = "fg.bin", address = 0x140000, words = 4096 },
    { target = "spr.bin", words = 4096, item = buffered },
    { target = "pal.bin", address = 0x180000, words = 16384 },
}
local controls = { [0x1c0000] = 0, [0x1c0002] = 0, [0x1c0004] = 0, [0x1c0006] = 0,
    [0x1c000a] = 0, [0x1d0006] = 0, [0x1d000c] = 0xff }
local function observe(address, data, mask)
    local old = controls[address]
    if old then controls[address] = (old & ~mask) | (data & mask) end
    return data
end
local scroll_tap = space:install_write_tap(0x1c0000, 0x1c000b, "scene_scroll", observe)
local control_tap = space:install_write_tap(0x1d0006, 0x1d000d, "scene_control", observe)

local base = os.getenv("SCENEDUMP_ROOT") or debug.getinfo(1, "S").source:sub(2):match("^(.*)/") or "."
local output = base .. "/scenes"
local scratch = base .. "/scratch"
local scheduled = os.getenv("SCENEDUMP_FRAMES")
local requested, pending = {}, 0
if scheduled then
    for text in scheduled:gmatch("%d+") do
        local number = tonumber(text)
        if not requested[number] then requested[number] = true; pending = pending + 1 end
    end
    assert(pending > 0, "No scheduled scenes")
end

local function mkdir(path)
    if lfs.attributes(path, "mode") ~= "directory" then assert(lfs.mkdir(path)) end
end

local function write(path, bytes)
    local file = assert(io.open(path, "wb"))
    assert(file:write(bytes))
    assert(file:close())
end

local serial = 0
local function capture(frame)
    local destination = output .. "/" .. frame
    if lfs.attributes(destination) then
        for _, name in ipairs({"dump.bin", "mmr.bin", "screen.png"}) do
            assert(lfs.attributes(destination .. "/" .. name, "mode") == "file", "Incomplete existing scene " .. frame)
        end
        print("PRESERVED " .. frame)
        return
    end
    mkdir(output)
    mkdir(scratch)
    serial = serial + 1
    local staging = string.format("%s/scene-%d-%d-%d", scratch, frame, os.time(), serial)
    assert(lfs.mkdir(staging))

    local dump = assert(io.open(staging .. "/dump.bin", "wb"))
    for _, block in ipairs(blocks) do
        local words = {}
        for i = 0, block.words - 1 do
            local word = block.item and block.item:read(i) or space:read_u16(block.address + i * 2)
            words[i + 1] = string.pack("<I2", word & 0xffff)
        end
        assert(dump:write(table.concat(words)), block.target)
    end
    assert(dump:close())

    local flip = flip_x:read(0) ~= 0 and 1 or 0
    assert((flip_y:read(0) ~= 0) == (flip ~= 0), "MAME flip axes disagree")
    local video = enabled:read(0) ~= 0 and 8 or 0
    write(staging .. "/mmr.bin", string.pack("<I2I2I2I2I2I2I2I2",
        controls[0x1c0000], controls[0x1c0002], controls[0x1c0004], controls[0x1c0006],
        (controls[0x1c000a] & 0xfffe) | flip, (controls[0x1d0006] & 0xfff7) | video,
        controls[0x1d000c], 0))
    assert(not screen:snapshot(staging .. "/screen.png"), "Snapshot failed")
    assert(os.rename(staging, destination))
    print("CAPTURED " .. frame)
end

local key = machine.input:code_from_token("KEYCODE_BACKSLASH")
local was_pressed, manual = false, false
local function take(frame)
    assert(scroll_tap and control_tap)
    local ok, message = xpcall(capture, debug.traceback, frame)
    if not ok then
        print("CAPTURE ERROR " .. message)
        if scheduled then machine:exit() else emu.pause() end
    end
    return ok
end

emu.register_periodic(function()
    if scheduled then return end
    local pressed = machine.input:code_pressed(key)
    if pressed and not was_pressed then manual = true end
    was_pressed = pressed
    if manual and machine.paused then
        manual = false
        take(screen:frame_number())
    end
end)

emu.register_frame_done(function()
    local frame = screen:frame_number()
    if requested[frame] then
        if not take(frame) then return end
        requested[frame] = nil
        pending = pending - 1
        if pending == 0 then
            write(assert(os.getenv("SCENEDUMP_DONE")), "complete\n")
            machine:exit()
        end
    elseif manual then
        manual = false
        take(frame)
    end
end)
