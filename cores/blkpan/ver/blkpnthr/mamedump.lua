-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Date: 25-11-2026

local lfs = require("lfs")
local script = debug.getinfo(1, "S").source:sub(2)
local here = assert(script:match("^(.*)/[^/]+$"), "Use an absolute autoboot script path")
if here:sub(1, 1) ~= "/" then here = lfs.currentdir() .. "/" .. here end
local machine = manager.machine
assert(machine.system.name == "blkpnthr", "This script requires blkpnthr")
assert(emu.app_version():match("^0%.282"), "MAME 0.282 is required")
local screen = assert(machine.screens[":screen"])
local cpu = assert(machine.devices[":maincpu"])
local mem = assert(cpu.spaces.program)
assert(screen:frame_number() <= 1, "Start the capture script at reset")

local function check_layout(name, expected)
    local file = assert(io.open(here .. "/../../cfg/" .. name, "rb"))
    local data = assert(file:read("*a"))
    assert(file:close())
    local hash = 0x811c9dc5
    for i = 1, #data do hash = ((hash ~ data:byte(i)) * 0x01000193) & 0xffffffff end
    assert(hash == expected, name .. " changed. Review the capture and restore layout.")
end

check_layout("mem.yaml", 0xab91d428)
check_layout("mmr.yaml", 0xc51ca1f3)

local target = tonumber(os.getenv("BLKPAN_CAPTURE_FRAME"))
local output = os.getenv("BLKPAN_SCENE_OUTPUT") or here .. "/scenes"
local scratch = here .. "/scratch/mamedump"
local replace = os.getenv("BLKPAN_SCENE_REPLACE") == "1"
local regions = {
    {name = "pal",    base = 0x080000, words =  4096, format = "B"},
    {name = "scroll", base = 0x180000, words =  2048, format = "B"},
    {name = "obj",    base = 0x190000, words =  2048, format = "B"},
    {name = "vram1",  base = 0x102000, words =  4096, format = "<I2"},
    {name = "vram2",  base = 0x100000, words =  4096, format = "B", alias = 0x104000},
    {name = "char",   base = 0x120000, words = 32768, format = "<I2"},
}
local latch = {base = 0x0a0000, size = 4, seek = 0, mask = 0x00ff, value = 0}
local pending, requested, key_down, disabled = nil, false, false, false
blkpan_scene_capture_hooks = {}
local hooks = blkpan_scene_capture_hooks

local function ensure_dir(path)
    if lfs.attributes(path, "mode") == "directory" then return end
    assert(lfs.mkdir(path))
end

ensure_dir(output)
ensure_dir(here .. "/scratch")
ensure_dir(scratch)

local function make_stage(frame)
    for attempt = 1, 1024 do
        local stage = string.format("%s/scene-%d-%d-%d", scratch, frame, os.time(), attempt)
        if lfs.mkdir(stage) then return stage end
    end
    error("Could not create capture staging directory")
end

local function capture_ram(region)
    local raw, packed = {}, {}
    for index = 0, region.words - 1 do
        local word = mem:read_u16(region.base + 2 * index)
        raw[index] = word
        packed[index + 1] = string.pack(region.format, region.format == "B" and (word & 0xff) or word)
    end
    return table.concat(packed), raw
end

local function hold_ram(scene, region, raw)
    local function install(base)
        scene.taps[#scene.taps + 1] = mem:install_write_tap(base, base + 2 * region.words - 1,
            "blkpan_hold_" .. region.name, function(address)
                return raw[(address - base) // 2]
            end)
    end
    install(region.base)
    if region.alias then install(region.alias) end
end

local function write_file(path, data)
    local file = assert(io.open(path, "wb"))
    assert(file:write(data))
    assert(file:close())
end

local function release_holds(scene)
    for _, tap in ipairs(scene.taps) do tap:remove() end
    scene.taps = {}
end

local function restore_machine(scene)
    release_holds(scene)
    if scene.state then
        assert(machine:buffer_load(scene.state), "Machine checkpoint restore failed")
        assert(screen:frame_number() == scene.frame, "Frame counter did not roll back")
        assert(cpu.state.PC.value == scene.pc, "CPU did not roll back")
        for index, data in ipairs(scene.ram) do
            assert(capture_ram(regions[index]) == data, "RAM did not roll back: " .. regions[index].name)
        end
        latch.value = scene.latch
        if scene.paused then emu.pause() end
    end
    scene.restored = true
end

local function begin_capture()
    local frame = screen:frame_number()
    local destination = output .. "/" .. frame
    assert(replace or not lfs.attributes(destination), "Scene already exists: " .. destination)
    local scene = {
        frame = frame, destination = destination, stage = make_stage(frame),
        paused = machine.paused, pc = cpu.state.PC.value, latch = latch.value,
        ram = {}, taps = {},
    }
    if not target then
        local state = machine:buffer_save()
        assert(type(state) == "string" and #state > 0, "Machine checkpoint failed")
        scene.state = state
    end
    pending = scene
    requested = false
    for index, region in ipairs(regions) do
        local data, raw = capture_ram(region)
        scene.ram[index] = data
        hold_ram(scene, region, raw)
    end
    local dump = table.concat(scene.ram)
    assert(#dump == 86016, "Incorrect RAM dump size")
    write_file(scene.stage .. "/dump.bin", dump)
    write_file(scene.stage .. "/mmr.bin", string.rep("\0", latch.seek) ..
        string.char(scene.latch) .. string.rep("\0", latch.size - 1))
    if scene.paused then emu.unpause() end
end

local function publish(scene)
    local backup
    if lfs.attributes(scene.destination) then
        assert(replace, "Scene already exists: " .. scene.destination)
        backup = scene.stage .. ".previous"
        assert(os.rename(scene.destination, backup))
    end
    local ok, message = os.rename(scene.stage, scene.destination)
    if not ok and backup then assert(os.rename(backup, scene.destination)) end
    assert(ok, message)
end

local function finish_capture(scene, frame)
    if frame == scene.frame then return end
    assert(frame == scene.frame + 1, "Unexpected snapshot frame: " .. frame)
    for index, region in ipairs(regions) do
        assert(capture_ram(region) == scene.ram[index], "Held state changed: " .. region.name)
    end
    assert(latch.value == scene.latch, "Held interrupt latch changed")
    assert(not screen:snapshot(scene.stage .. "/screen.png"), "Native snapshot failed")
    local snapshot = assert(lfs.attributes(scene.stage .. "/screen.png", "size"))
    assert(snapshot > 0, "Empty native snapshot")
    restore_machine(scene)
    publish(scene)
    pending = nil
    print("CAPTURE_OK " .. scene.frame)
    if target then machine:exit() end
end

local function fail(message)
    local scene = pending
    if scene and not scene.restored then
        local ok, restore_error = pcall(restore_machine, scene)
        if not ok then
            print("CAPTURE_ROLLBACK_FAILED " .. tostring(restore_error))
            disabled = true
            emu.pause()
        end
    end
    pending, requested = nil, false
    print("CAPTURE_FAILED " .. tostring(message))
    if target then machine:exit() end
end

hooks.latch = mem:install_write_tap(latch.base, latch.base + 1, "blkpan_intlatch",
    function(_, data, mask)
        if (mask & latch.mask) == 0 then return end
        if pending and not pending.restored then
            return (data & 0xff00) | pending.latch
        end
        latch.value = data & latch.mask
    end)
hooks.reset = emu.add_machine_reset_notifier(function() latch.value = 0 end)
hooks.frame = emu.add_machine_frame_notifier(function()
    if disabled then return end
    local frame = screen:frame_number()
    local ok, message = pcall(function()
        if pending then
            finish_capture(pending, frame)
        elseif target and frame >= target then
            assert(frame == target, "Missed requested frame " .. target)
            begin_capture()
        elseif requested then
            begin_capture()
        end
    end)
    if not ok then fail(message) end
end)

if not target then
    local input = machine.input
    local hotkey = input:seq_from_tokens("KEYCODE_BACKSLASH")
    emu.register_frame_done(function()
        if disabled or pending then return end
        local pressed = input:seq_pressed(hotkey)
        if pressed and not key_down then requested = true end
        key_down = pressed
        if requested and machine.paused then
            local ok, message = pcall(begin_capture)
            if not ok then fail(message) end
        end
    end)
    print("CAPTURE_READY " .. input:seq_name(hotkey))
end
