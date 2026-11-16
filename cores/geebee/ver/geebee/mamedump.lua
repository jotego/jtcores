-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Date: 10-11-2026

if _G.jtgeebee_capture then return end
local session={}
_G.jtgeebee_capture=session
io.stdout:setvbuf("no")

local machine=manager.machine
assert(machine.system.name=="geebee", "Expected geebee")
local screen=assert(machine.screens[":screen"])
local video=assert(machine.memory.shares[":geebee_videoram"])
assert(video.size==1024 and video.bitwidth==8, "Gee Bee video RAM layout changed")
local root=assert(machine.devices[":"])
local layout={
    ram={name="video",source=":geebee_videoram",bytes=1024,target="vram.bin"},
    mmr={
        {name="bgw",item="0/m_geebee_bgw",target="bgw_eff"},
        {name="ball_on",item="0/m_ball_on",target="ball_on_eff"},
        {name="ball_h",item="0/m_ball_h",target="ball_x_eff"},
        {name="ball_v",item="0/m_ball_v",target="ball_y_eff"},
        {name="flip_x",item="0/m_flip_screen_x",target="flip_eff"},
        {name="flip_y",item="0/m_flip_screen_y",target="flip_eff"}
    }
}
for _,block in ipairs(layout.mmr) do
    local item=assert(root.items[block.item],"Missing MAME item "..block.item)
    block.reader=emu.item(item)
end
local path=os.getenv("SCENEDUMP_ROOT") or debug.getinfo(1,"S").source:sub(2):match("^(.*)/") or "."
local requested=os.getenv("SCENEDUMP_FRAMES")
local replace=os.getenv("SCENEDUMP_REPLACE")=="1"
local requests,pending={},0
if requested then
    for number in requested:gmatch("%d+") do
        local frame=tonumber(number)
        if not requests[frame] then requests[frame]=true; pending=pending+1 end
    end
    assert(pending>0,"No capture frames")
end
local function quote(value) return "'"..value:gsub("'","'\\''").."'" end
local function command(value) assert(os.execute(value),value) end
local function exists(value)
    local ok=os.execute("test -e "..quote(value))
    return ok==true or ok==0
end
local function write_file(name,value)
    local file=assert(io.open(name,"wb"))
    assert(file:write(value))
    assert(file:close())
end
local busy,serial=false,0
local function capture(frame)
    if busy then return end
    local destination=path.."/scenes/"..frame
    if exists(destination) and not replace then print("PRESERVED "..destination); return end
    busy=true
    serial=serial+1
    local staging=path.."/scratch/capture-"..frame.."-"..os.time().."-"..serial
    local was_paused=machine.paused
    local checkpoint=machine:buffer_save()
    emu.pause()
    local ok,message=xpcall(function()
        command("mkdir -p "..quote(staging).." "..quote(path.."/scenes"))
        local bytes={}
        for address=0,layout.ram.bytes-1 do
            bytes[address+1]=string.char(video:read_u8(address))
        end
        write_file(staging.."/dump.bin",table.concat(bytes))
        local regs={}
        for _,block in ipairs(layout.mmr) do
            local value=block.reader:read(0)
            assert(value>=0 and value<=255,"Register out of byte range: "..block.name)
            regs[#regs+1]=string.char(value)
        end
        assert(regs[5]==regs[6],"MAME horizontal and vertical flip differ")
        write_file(staging.."/mmr.bin",table.concat(regs))
        screen:snapshot(staging.."/screen.png")
        local previous=staging.."-previous"
        if exists(destination) then assert(os.rename(destination,previous)) end
        local published,err=os.rename(staging,destination)
        if not published then
            if exists(previous) then os.rename(previous,destination) end
            error(err)
        end
        if exists(previous) then command("rm -rf "..quote(previous)) end
        print("CAPTURED geebee "..frame)
    end,debug.traceback)
    local restored,restore_error=pcall(function() assert(machine:buffer_load(checkpoint)) end)
    busy=false
    if not restored then emu.pause(); error("Capture rollback failed: "..tostring(restore_error)) end
    if not was_paused then emu.unpause() end
    if not ok then emu.pause(); error(message) end
end
local key=machine.input:code_from_token("KEYCODE_BACKSLASH")
local last_key,manual_pending=false,false
emu.register_periodic(function()
    if requested then return end
    local pressed=machine.input:code_pressed(key)
    if pressed and not last_key and not busy then manual_pending=true end
    last_key=pressed
    if manual_pending and machine.paused then
        manual_pending=false
        capture(screen:frame_number())
    end
end)
emu.register_frame_done(function()
    if busy then return end
    local frame=screen:frame_number()
    if requested and requests[frame] then
        local ok,message=pcall(capture,frame)
        if not ok then print("CAPTURE ERROR "..tostring(message)); machine:exit(); return end
        requests[frame]=nil
        pending=pending-1
        if pending==0 then
            local done=os.getenv("SCENEDUMP_DONE")
            if done then write_file(done,"complete\n") end
            machine:exit()
        end
    elseif manual_pending then
        manual_pending=false
        local ok,message=pcall(capture,frame)
        if not ok then print("CAPTURE ERROR "..tostring(message)); emu.pause() end
    end
end)
