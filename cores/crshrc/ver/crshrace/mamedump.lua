-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Date: 26-10-2026

if _G.jtcrshrc_scene_capture then return end
local session = {completed=0, key_down=false}
io.stdout:setvbuf("no")

local machine = manager.machine
assert(machine.system.name == "crshrace", "This capture binding requires crshrace")
local screen = assert(machine.screens[":screen"], "Missing :screen")
local space = assert(machine.devices[":maincpu"], "Missing :maincpu").spaces["program"]
local script = debug.getinfo(1, "S").source:sub(2)
local script_dir = assert(script:match("^(.*)/"), "Load mamedump.lua by its path")
local root = os.getenv("SCENEDUMP_ROOT") or script_dir
local replace = os.getenv("SCENEDUMP_REPLACE") == "1"
local scheduled = os.getenv("SCENEDUMP_FRAMES")
local done_file = os.getenv("SCENEDUMP_DONE")
local layout = {
    ram = {
        {name="fgvram", address=0xffd000, bytes=4096, offset=0, target="fgvram.bin"},
        {name="rozvram", address=0xd00000, bytes=8192, offset=4096, target="rozvram.bin"},
        {name="sprcg", address=0xa00000, bytes=65536, offset=12288, target="sprcg.bin"},
        {name="sprvram", address=0xe00000, bytes=8192, offset=77824, target="sprvram.bin"},
        {name="pal", address=0xffe000, bytes=4096, offset=86016, target="pal.bin"}
    },
    buffers = {
        {name="sprcg", device=":spriteram.1", bytes=65536, offset=12288, target="sprcg_buf.bin"},
        {name="sprvram", device=":spriteram.0", bytes=8192, offset=77824, target="sprvram_buf.bin"}
    },
    mmr = {
        {name="control", bytes=8, seek=0, target="u_main.u_scene", file="mmr.bin"},
        {name="psac", address=0xfff020, bytes=32, seek=8,
         target="u_video.u_roz.u_xy.mmr", file="psac.bin"}
    },
    definitions = {
        {"cfg/mem.yaml", "584487759 2362"},
        {"cfg/mmr.yaml", "2798758293 1024"},
        {"ver/game/rest2bin.sh", "297294942 1208"}
    }
}
session.layout = layout
for _, block in ipairs(layout.buffers) do
    local device=assert(machine.devices[block.device], "Missing "..block.device)
    block.item=emu.item((assert(device.items["0/m_buffered"], "Missing buffered sprite state")))
end

local function quote(value) return "'" .. value:gsub("'", "'\\''") .. "'" end
local function command(value)
    local ok = os.execute(value)
    assert(ok == true or ok == 0, "Command failed: " .. value)
end
local function exists(path)
    local result = os.execute("test -e " .. quote(path))
    return result == true or result == 0
end
local function write_file(path, data)
    local file = assert(io.open(path, "wb"))
    assert(file:write(data))
    assert(file:close())
end
local function read_file(path)
    local file = assert(io.open(path, "rb"))
    local data = assert(file:read("*a"))
    assert(file:close())
    return data
end
local function validate_scene(path)
    assert(#read_file(path.."/dump.bin") == 90112, "Invalid dump size")
    assert(#read_file(path.."/mmr.bin") == 40, "Invalid MMR size")
    for _, block in ipairs(layout.buffers) do
        assert(#read_file(path.."/"..block.target) == block.bytes, "Invalid sprite snapshot")
    end
    assert(read_file(path.."/screen.png"):sub(1,8) == "\137PNG\r\n\26\n", "Missing PNG")
end
for _, definition in ipairs(layout.definitions) do
    local path = script_dir .. "/../../" .. definition[1]
    local pipe = assert(io.popen("cksum < " .. quote(path), "r"))
    local checksum = pipe:read("*a"):match("^(%d+%s+%d+)")
    pipe:close()
    assert(checksum == definition[2], "Capture layout changed: " .. path)
end
assert(screen:frame_number() <= 2,
    "Load this script at startup with -autoboot_delay 0; register shadows require reset")

local function new_bytes(size)
    local bytes = {}
    for i=1,size do bytes[i]=0 end
    return bytes
end
local function bytes_to_string(bytes)
    local result = {}
    for i,value in ipairs(bytes) do result[i]=string.char(value) end
    return table.concat(result)
end
local function set_word(bytes, offset, data, mask)
    if mask & 0x00ff ~= 0 then bytes[offset+1]=data & 0xff end
    if mask & 0xff00 ~= 0 then bytes[offset+2]=(data >> 8) & 0xff end
end
local function get_word(bytes, offset)
    return bytes[offset+1] | (bytes[offset+2] << 8)
end
local registers
local function reset_shadow()
    assert(not session.pending, "Reset during a held capture")
    registers = {control=new_bytes(layout.mmr[1].bytes), psac=new_bytes(layout.mmr[2].bytes)}
end
session.reset_subscription = emu.add_machine_reset_notifier(reset_shadow)
reset_shadow()

local function read_ram()
    local parts = {}
    for _, block in ipairs(layout.ram) do
        local data = space:read_range(block.address, block.address+block.bytes-1, 8)
        assert(#data == block.bytes, "Short RAM block: " .. block.name)
        parts[#parts+1] = data
    end
    return table.concat(parts)
end
local function read_buffers()
    local result = {}
    for _, block in ipairs(layout.buffers) do
        local parts={}
        for i=0,block.bytes//2-1 do parts[#parts+1]=string.pack(">I2",block.item:read(i)) end
        result[block.name]=table.concat(parts)
    end
    return result
end
local function hold_ram(ram,buffers)
    for _,block in ipairs(layout.buffers) do
        ram=ram:sub(1,block.offset)..buffers[block.name]..ram:sub(block.offset+block.bytes+1)
    end
    return ram
end
local function read_mmr()
    local parts = {}
    for _, block in ipairs(layout.mmr) do
        parts[#parts+1] = bytes_to_string(registers[block.name])
    end
    return table.concat(parts)
end
session.taps = {}
for _, block in ipairs(layout.ram) do
    session.taps[#session.taps+1] = space:install_write_tap(
        block.address, block.address+block.bytes-1, "crshrace_hold_"..block.name,
        function(address, data, mask)
            if session.pending then
                local offset=block.offset+(address-block.address)
                local high,low=session.pending.hold_ram:byte(offset+1, offset+2)
                return (high << 8) | low
            end
            return data
        end)
end
session.taps[#session.taps+1] = space:install_write_tap(
    0xfff000, 0xfff001, "crshrace_control", function(address, data, mask)
        if session.pending then return get_word(registers.control, 0) end
        if mask & 0x00ff ~= 0 then registers.control[1]=data & 0xff end
        return data
    end)
session.taps[#session.taps+1] = space:install_write_tap(
    0xffc000, 0xffc001, "crshrace_bank", function(address, data, mask)
        if session.pending then return registers.control[2] end
        if mask & 0x00ff ~= 0 then registers.control[2]=data & 0xff end
        return data
    end)
session.taps[#session.taps+1] = space:install_write_tap(
    layout.mmr[2].address, layout.mmr[2].address+layout.mmr[2].bytes-1,
    "crshrace_psac", function(address, data, mask)
        local offset=address-layout.mmr[2].address
        if session.pending then return get_word(registers.psac, offset) end
        set_word(registers.psac, offset, data, mask)
        return data
    end)

local requests, remaining = {}, 0
if scheduled then
    for value in scheduled:gmatch("%d+") do
        local frame=assert(tonumber(value))
        assert(frame > 0, "Scene frame must be positive")
        if not requests[frame] then requests[frame]=true; remaining=remaining+1 end
    end
    assert(remaining > 0, "No scheduled frames")
end
local function finish_request(frame)
    if scheduled and requests[frame] then
        requests[frame]=nil
        remaining=remaining-1
        if remaining == 0 then
            if done_file then write_file(done_file, "complete\n") end
            machine:exit()
        end
    end
end
local serial = 0
local function capture(frame)
    if session.pending then return false end
    frame=frame or screen:frame_number()
    local destination=root .. "/scenes/" .. frame
    if exists(destination) and not replace then
        validate_scene(destination)
        print("PRESERVED " .. destination)
        finish_request(frame)
        return false
    end
    assert((registers.psac[15] & 0x40) == 0,
        "PSAC2 line mode needs a line-RAM capture/restore binding")
    serial=serial+1
    local staging=root .. "/scratch/capture/stage-" .. frame .. "-" .. os.time() .. "-" .. serial
    command("mkdir -p " .. quote(staging) .. " " .. quote(root.."/scenes"))
    local ram,buffers=read_ram(),read_buffers()
    session.pending = {
        frame=frame, destination=destination, staging=staging,
        checkpoint=machine:buffer_save(), was_paused=machine.paused,
        ram=ram, hold_ram=hold_ram(ram,buffers), buffers=buffers, mmr=read_mmr()
    }
    for _,block in ipairs(layout.buffers) do
        local address
        for _,live in ipairs(layout.ram) do if live.name==block.name then address=live.address end end
        assert(address)
        local data=buffers[block.name]
        for i=0,block.bytes-2,2 do space:write_u16(address+i,string.unpack(">I2",data,i+1)) end
    end
    if session.pending.was_paused then emu.unpause() end
    print("HOLD " .. frame)
    return true
end
session.capture = capture

local function publish(pending)
    local expected={["dump.bin"]=true, ["mmr.bin"]=true, ["screen.png"]=true, ["sprcg_buf.bin"]=true, ["sprvram_buf.bin"]=true}
    if exists(pending.destination) then
        local pipe=assert(io.popen("find " .. quote(pending.destination) .. " -mindepth 1 -maxdepth 1 -print", "r"))
        for path in pipe:lines() do
            assert(expected[path:match("([^/]+)$")], "Unrelated scene file preserved: " .. path)
        end
        pipe:close()
        assert(os.rename(pending.destination, pending.staging.."-previous"))
    end
    local ok,message=os.rename(pending.staging, pending.destination)
    if not ok then
        if exists(pending.staging.."-previous") then
            assert(os.rename(pending.staging.."-previous", pending.destination))
        end
        error(message)
    end
end
local function finalize()
    local pending=assert(session.pending)
    emu.pause()
    local ok,message=xpcall(function()
        assert(read_ram() == pending.hold_ram, "Video RAM changed during held frame")
        assert(read_mmr() == pending.mmr, "Video registers changed during held frame")
        write_file(pending.staging.."/dump.bin", pending.ram)
        write_file(pending.staging.."/mmr.bin", pending.mmr)
        local buffers=read_buffers()
        for _,block in ipairs(layout.buffers) do
            assert(buffers[block.name]==pending.buffers[block.name], "Sprite buffer changed during held frame")
            write_file(pending.staging.."/"..block.target,pending.buffers[block.name])
        end
        screen:snapshot(pending.staging.."/screen.png")
        validate_scene(pending.staging)
    end, debug.traceback)
    local restored,restore_error=pcall(function()
        assert(machine:buffer_load(pending.checkpoint), "Whole-machine rollback failed")
    end)
    session.pending=nil
    if not restored then
        emu.pause()
        error("Capture rollback failed; machine paused: " .. tostring(restore_error))
    end
    if not pending.was_paused then emu.unpause() end
    if not ok then emu.pause(); error(message) end
    publish(pending)
    session.completed=session.completed+1
    session.last_frame=pending.frame
    session.last_rollback=true
    session.last_was_paused=pending.was_paused
    print("CAPTURED crshrace " .. pending.frame .. " rollback=ok")
    finish_request(pending.frame)
end
emu.register_frame_done(function()
    local frame=screen:frame_number()
    local ok,message=xpcall(function()
        if session.pending then
            if frame > session.pending.frame then finalize() end
        elseif scheduled and requests[frame] then
            capture(frame)
        end
    end, debug.traceback)
    if not ok then
        emu.pause()
        print("CAPTURE ERROR " .. tostring(message))
        if scheduled then machine:exit() end
    end
end)
local key=machine.input:code_from_token(os.getenv("SCENEDUMP_KEY") or "KEYCODE_BACKSLASH")
function session.key_event(pressed)
    local rising=pressed and not session.key_down
    session.key_down=pressed
    if rising and not scheduled and not session.pending then
        local ok,message=pcall(capture, screen:frame_number())
        if not ok then emu.pause(); print("CAPTURE ERROR " .. tostring(message)) end
    end
end
emu.register_periodic(function()
    if not scheduled then session.key_event(machine.input:code_pressed(key)) end
end)
_G.jtcrshrc_scene_capture = session
machine:soft_reset()
