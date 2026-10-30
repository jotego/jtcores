-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Date: 29-10-2026

assert(not mamedump, "mamedump.lua is already loaded")
assert(emu.app_version() == "0.289" or os.getenv("MAMEDUMP_VERSION_OK") == "1",
    "Use MAME 0.289 for this capture binding, or set MAMEDUMP_VERSION_OK=1 for a user-selected binary")
local lfs = require("lfs")
local m = manager.machine
assert(m.system.name == "apache3", "This dump script is for apache3")
local source = debug.getinfo(1, "S").source:gsub("^@", "")
local base = source:match("^(.*)/") or "."
local output = os.getenv("MAMEDUMP_OUTPUT") or base.."/scenes"
local work = os.getenv("MAMEDUMP_WORK") or base.."/scratch/mamedump"
local target = tonumber(os.getenv("MAMEDUMP_FRAME") or "")
local replace = os.getenv("MAMEDUMP_REPLACE") == "1"
local screen = assert(m.screens[":screen"])
assert(screen:frame_number() <= 1, "Load mamedump.lua at MAME startup")
local root = m.devices[":"]
local mem = m.devices[":maincpu"].spaces.program
local sub = m.devices[":sub"].spaces.program
local z80 = m.devices[":sub2"].spaces.program
local rotate = emu.item(assert(root.items["0/m_apache3_rotate_ctrl"]))
local rotidx = emu.item(assert(root.items["0/m_apache3_rot_idx"]))
local roadz = emu.item(assert(root.items["0/m_apache3_road_z"]))
local roadx = emu.item(assert(root.items["0/m_apache3_road_x_ram"]))
local pending
local held, requested, fatal = false, false, false
local key = m.input:seq_from_tokens("KEYCODE_BACKSLASH")
mamedump = {}

local function mkdir(path)
    local current = path:sub(1,1) == "/" and "/" or ""
    for part in path:gmatch("[^/]+") do
        current = current..part.."/"
        if not lfs.attributes(current) then assert(lfs.mkdir(current)) end
        assert(lfs.attributes(current, "mode") == "directory", "Not a directory: "..current)
    end
end
mkdir(output)
mkdir(work)
local function log(message)
    print(message)
    local f = assert(io.open(work.."/capture.log", "a"))
    f:write(message.."\n")
    f:close()
end
local function write(path, data)
    local f = assert(io.open(path, "wb"))
    assert(f:write(data))
    assert(f:close())
end
local mmr_layout = {
    { name="rotation", size=32, seek=0, restore="jtapach3_ground" },
    { name="road", size=4, seek=32, restore="jtapach3_sub" },
}
mamedump.mmr_layout = mmr_layout

local function read_words(space, first, size)
    local b={}
    for a=first,first+size-2,2 do b[#b+1]=string.pack("<I2",space:read_u16(a)) end
    return table.concat(b)
end
local function read_state()
    local blocks={
        read_words(mem,0x4000,0x4000),
        read_words(mem,0xc000,0x2000),
        read_words(sub,0x90000,0x4000),
        read_words(sub,0x9a000,0x200),
        read_words(mem,0x8000,0x1000),
    }
    local b={}
    for i=0,255 do b[#b+1]=string.pack("<I2",roadx:read(i)&0xffff) end
    blocks[6]=table.concat(b)
    blocks[7]=read_words(sub,0xd0000,0x10000)
    b={}
    for i=0,11 do b[#b+1]=string.pack("<I2",rotate:read(i)&0xffff) end
    blocks[8]=table.concat(b)..string.char(rotidx:read(0)&0xff)..string.rep("\0",7)
    blocks[9]=string.char(roadz:read(0)&0xff)..string.rep("\0",3)
    return blocks
end
local function hold(space, lo, hi, name, reader)
    pending.taps[#pending.taps+1] = space:install_write_tap(lo,hi,name,function(a) return reader(a) end)
end
local function freeze()
    for _,r in ipairs({{0x4000,0x7fff},{0x8000,0x8fff},{0xc000,0xdfff}}) do
        hold(mem,r[1],r[2],"dump_main_"..r[1],function(a) return mem:read_u16(a) end)
    end
    for _,r in ipairs({{0x90000,0x93fff},{0x9a000,0x9a1ff},{0xd0000,0xdffff}}) do
        hold(sub,r[1],r[2],"dump_sub_"..r[1],function(a) return sub:read_u16(a) end)
    end
    hold(sub,0xa0000,0xa0001,"dump_rotate",function() return rotate:read(rotidx:read(0)) end)
    hold(sub,0xc0000,0xc0001,"dump_roadz",function() return roadz:read(0) end)
    pending.taps[#pending.taps+1]=z80:install_write_tap(0x8000,0xffff,"dump_roadx",function(a,d)
        local v=a&0xfff
        if (roadx:read(d)&0xfff)==v then return d end
        for i=0,255 do if (roadx:read(i)&0xfff)==v then return i end end
        pending.roadx_changed=true
        return d
    end)
end
local function unfreeze(p)
    for _,tap in ipairs(p.taps) do tap:remove() end
    p.taps={}
end
local function restore(p)
    unfreeze(p)
    assert(m:buffer_load(p.state), "Could not restore machine after capture")
    assert(screen:frame_number()==p.frame, "Machine frame did not restore")
    local current=read_state()
    for i,bytes in ipairs(p.blocks) do assert(current[i]==bytes, "Restored video differs at block "..i) end
    if p.paused then emu.pause() end
    p.restored=true
end
local function begin_capture()
    assert(not pending and not fatal, "Capture already pending or unavailable")
    local frame=screen:frame_number()
    local destination=output.."/"..frame
    if lfs.attributes(destination) and not replace then
        log("MAMEDUMP_EXISTS frame="..frame)
        m:popmessage("Scene "..frame.." exists; use --replace to replace it")
        requested=false
        if target then m:exit() end
        return
    end
    local p={frame=frame,paused=m.paused,taps={},destination=destination}
    if not target then
        p.state=m:buffer_save()
        assert(p.state and #p.state>0, "MAME could not checkpoint this machine")
    end
    p.blocks=read_state()
    local serial=0
    repeat
        p.path=work.."/"..frame..".pending-"..serial
        serial=serial+1
    until not lfs.attributes(p.path)
    assert(lfs.mkdir(p.path))
    pending=p
    local dump=table.concat(p.blocks, "", 1, 7)
    assert(#dump==111616, "Unexpected video dump size")
    write(p.path.."/dump.bin",dump)
    write(p.path.."/mmr.bin",p.blocks[8]..p.blocks[9])
    freeze()
    requested=false
    if p.paused then emu.unpause() end
end
local function finish_capture()
    local p=assert(pending)
    local frame=screen:frame_number()
    if frame==p.frame then return end
    assert(frame==p.frame+1, "Missed held reference frame")
    assert(not p.roadx_changed, "Could not hold road offset write")
    local current=read_state()
    for i,bytes in ipairs(p.blocks) do assert(current[i]==bytes, "Held video changed at block "..i) end
    assert(not screen:snapshot(p.path.."/screen.png"), "Snapshot failed")
    if target then unfreeze(p) else restore(p) end
    local backup
    if lfs.attributes(p.destination) then
        local serial=0
        repeat
            backup=work.."/"..p.frame..".previous-"..serial
            serial=serial+1
        until not lfs.attributes(backup)
        assert(os.rename(p.destination,backup))
    end
    local published,err=os.rename(p.path,p.destination)
    if not published and backup then assert(os.rename(backup,p.destination), "Could not restore previous scene") end
    assert(published,err)
    pending=nil
    mamedump.last_frame=p.frame
    log("MAMEDUMP_OK frame="..p.frame.." reference="..frame.." bytes=111616 mmr=36 resumed="..tostring(not target))
    m:popmessage("Saved scene "..p.frame)
    if target then m:exit() end
end
local function fail(message)
    local p=pending
    if p then
        local ok,err=pcall(function()
            if p.state and not p.restored then restore(p) else unfreeze(p) end
        end)
        if not ok then
            fatal=true
            emu.pause()
            message=tostring(message).."; rollback failed: "..tostring(err)
        end
    end
    pending=nil
    requested=false
    log("MAMEDUMP_ERROR "..tostring(message))
    m:popmessage("Capture failed; see "..work.."/capture.log")
    if target then m:exit() end
end
function mamedump.capture()
    local ok,err=pcall(begin_capture)
    if not ok then fail(err) end
end
emu.register_frame_done(function()
    if target or fatal then return end
    local pressed=m.input:seq_pressed(key)
    if pressed and not held and not pending then requested=true end
    held=pressed
    if requested and m.paused then mamedump.capture() end
end)
mamedump.frame_notifier=emu.add_machine_frame_notifier(function()
    if fatal then return end
    local ok,err=pcall(function()
        if pending then finish_capture();return end
        local frame=screen:frame_number()
        if target and frame>=target then
            assert(frame==target, "Missed requested frame")
            begin_capture()
        elseif requested then begin_capture() end
    end)
    if not ok then fail(err) end
end)
log("MAMEDUMP_READY game=apache3 mame="..emu.app_version().." mode="..(target and "frame" or "keypress"))
if not target then m:popmessage("Capture scene: backslash (\\)") end
