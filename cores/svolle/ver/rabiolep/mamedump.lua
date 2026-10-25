-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Date: 25-10-2026

if _G.jtsvolle_scene_capture then return end
local session={}
_G.jtsvolle_scene_capture=session
io.stdout:setvbuf("no")

local machine = manager.machine
local screen = machine.screens[":screen"]
local space = machine.devices[":maincpu"].spaces["program"]
local game = machine.system.name
assert(game=="svolley" or game=="rabiolep", "Unsupported machine: "..game)
local root = os.getenv("SCENEDUMP_ROOT") or debug.getinfo(1,"S").source:sub(2):match("^(.*)/") or "."
local scheduled = os.getenv("SCENEDUMP_FRAMES")
local replace = os.getenv("SCENEDUMP_REPLACE")=="1"
local layout = {
    ram = {
        {name="vram0", address=0x80000, bytes=8192, offset=0, target="vram0.bin"},
        {name="vram1", address=0x82000, bytes=8192, offset=8192, target="vram1.bin"},
        {name="oram", address=0x60000, bytes=4096, offset=16384, target="oram.bin"},
        {name="pal", address=0xa0000, bytes=2048, offset=20480, target="pal.bin"}
    },
    mmr = {
        {name="control", address=0xc0000, bytes=32, seek=0, target="u_main.u_control"},
        {name="gga", address=0xc0008, bytes=16, seek=32, target="u_main.u_gga"}
    }
}
if game=="rabiolep" then
    table.insert(layout.ram,{name="bitmap",address=0x40000,bytes=65536,offset=22528,target="bitmap.bin"})
end
local function quote(s) return "'"..s:gsub("'","'\\''").."'" end
local function command(s) assert(os.execute(s),s) end
local function exists(p)
    local result=os.execute("test -e "..quote(p))
    return result==true or result==0
end
local function write_file(p,bytes)
    local f=assert(io.open(p,"wb")); assert(f:write(bytes)); assert(f:close())
end
local registers, gga_index, ready = {}, 0, false
local function reset_shadow()
    registers={}
    for _,block in ipairs(layout.mmr) do
        registers[block.name]={}
        for i=1,block.bytes do registers[block.name][i]=0 end
    end
    gga_index=0
    ready=true
end
session.reset_subscription=emu.add_machine_reset_notifier(reset_shadow)
reset_shadow()
session.tap=space:install_write_tap(0xc0000,0xc003f,"svolle_capture",function(address,data,mask)
    local a=(address&0xfffff)-layout.mmr[1].address
    local control=registers.control
    if (a<=6 and mask==0xffff) or a==12 then
        if mask&0xff~=0 then control[a+1]=data&0xff end
        if mask&0xff00~=0 then control[a+2]=(data>>8)&0xff end
    elseif (a==16 or a==18) and mask&0xff~=0 then
        control[a+1]=data&0xff
    elseif a==40 and mask&0xff~=0 then
        gga_index=data&15
    elseif a==8 and mask&0xff~=0 then
        registers.gga[gga_index+1]=data&0xff
    end
end)
local requests, pending = {}, 0
if scheduled then
    for value in scheduled:gmatch("%d+") do
        local frame=tonumber(value)
        if not requests[frame] then requests[frame]=true; pending=pending+1 end
    end
end
local busy, serial = false, 0
local function capture(frame)
    if busy or not ready then return end
    local destination=root.."/scenes/"..frame
    if exists(destination) and not replace then print("PRESERVED "..destination); return end
    busy=true
    serial=serial+1
    local staging=root.."/scratch/capture-"..frame.."-"..os.time().."-"..serial
    local was_paused=machine.paused
    local checkpoint=machine:buffer_save()
    emu.pause()
    local ok,message=xpcall(function()
        command("mkdir -p "..quote(staging).." "..quote(root.."/scenes"))
        if exists(destination) then command("cp -R "..quote(destination.."/.").." "..quote(staging.."/")) end
        local ram={}
        for _,block in ipairs(layout.ram) do
            ram[#ram+1]=space:read_range(block.address,block.address+block.bytes-1,8)
        end
        write_file(staging.."/dump.bin",table.concat(ram))
        local mmr={}
        for _,block in ipairs(layout.mmr) do
            for _,byte in ipairs(registers[block.name]) do mmr[#mmr+1]=string.char(byte) end
        end
        write_file(staging.."/mmr.bin",table.concat(mmr))
        screen:snapshot(staging.."/screen.png")
        if exists(destination) then assert(os.rename(destination,staging.."-previous")) end
        local published,err=os.rename(staging,destination)
        if not published then
            if exists(staging.."-previous") then os.rename(staging.."-previous",destination) end
            error(err)
        end
        print("CAPTURED "..game.." "..frame)
    end,debug.traceback)
    local restored,restore_error=pcall(function() assert(machine:buffer_load(checkpoint)) end)
    busy=false
    if not restored then
        emu.pause(); error("Capture rollback failed: "..tostring(restore_error))
    end
    if not was_paused then emu.unpause() end
    if not ok then emu.pause(); error(message) end
end
emu.register_frame_done(function()
    if not scheduled or busy or not ready then return end
    local frame=screen:frame_number()
    if requests[frame] then
        local ok,message=pcall(capture,frame)
        if not ok then print("CAPTURE ERROR "..tostring(message)); machine:exit(); return end
        requests[frame]=nil
        pending=pending-1
        if pending==0 then
            local done=os.getenv("SCENEDUMP_DONE")
            if done then write_file(done,"complete\n") end
            machine:exit()
        end
    end
end)
local key=machine.input:code_from_token("KEYCODE_BACKSLASH")
local last_key=false
emu.register_periodic(function()
    if scheduled then return end
    local pressed=machine.input:code_pressed(key)
    if pressed and not last_key and not busy then capture(screen:frame_number()) end
    last_key=pressed
end)
machine:soft_reset()
