-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Date: 01-11-2026

if _G.jtttnose_scene_capture then return end
local session={completed=0,key_down=false}
io.stdout:setvbuf("no")
assert(emu.app_version()=="0.282", "MAME 0.282 is required")
local machine=manager.machine
assert(machine.system.name=="tail2nos", "This capture binding requires tail2nos")
local screen=assert(machine.screens[":screen"])
local space=assert(machine.devices[":maincpu"]).spaces.program
local script_dir=assert(debug.getinfo(1,"S").source:sub(2):match("^(.*)/"))
local root=os.getenv("SCENEDUMP_ROOT") or script_dir
local replace=os.getenv("SCENEDUMP_REPLACE")=="1"
local scheduled=os.getenv("SCENEDUMP_FRAMES")
local done_file=os.getenv("SCENEDUMP_DONE")
local layout={
    ram={
        {name="rozgfx",address=0x400000,bytes=131072,offset=0,target="rozgfx.bin",stride=1},
        {name="psac0",address=0x500001,bytes=1024,offset=131072,target="psac0.bin",stride=2},
        {name="psac1",address=0x500801,bytes=1024,offset=132096,target="psac1.bin",stride=2},
        {name="oram",address=0xffc000,bytes=4096,offset=133120,target="oram.bin",stride=1},
        {name="txram",address=0xffd000,bytes=4096,offset=137216,target="txram.bin",stride=1},
        {name="pal",address=0xffe000,bytes=4096,offset=141312,target="pal.bin",stride=1}
    },
    mmr={
        {name="k051316",bytes=16,seek=0,target="u_video.u_roz.u_psac.u_mmr",file="psac_mmr.bin"},
        {name="video",bytes=4,seek=16,target="u_video.u_control",file="mmr.bin"},
        {name="gga",bytes=16,seek=20,target="u_video.u_gga",file="gga.bin"}
    },
    definitions={
        {"cfg/mem.yaml", "2951119864 1706"},
        {"cfg/mmr.yaml", "1035701767 1612"},
        {"ver/game/rest2bin.sh", "1061297721 1133"},
        {"hdl/jtttnose_video.v", "3956890782 5694"},
        {"hdl/jtttnose_roz.v", "2309546994 2651"}
    }
}
session.layout=layout
local function quote(s) return "'"..s:gsub("'","'\\''").."'" end
local function command(s)
    local ok=os.execute(s); assert(ok==true or ok==0,"Command failed: "..s)
end
local function exists(p)
    local ok=os.execute("test -e "..quote(p)); return ok==true or ok==0
end
local function read_file(p)
    local f=assert(io.open(p,"rb"));local b=assert(f:read("*a"));assert(f:close());return b
end
local function write_file(p,b)
    local f=assert(io.open(p,"wb"));assert(f:write(b));assert(f:close())
end
local function validate_scene(p)
    assert(#read_file(p.."/dump.bin")==145408,"Invalid RAM dump size")
    assert(#read_file(p.."/mmr.bin")==36,"Invalid MMR dump size")
    assert(read_file(p.."/screen.png"):sub(1,8)=="\137PNG\r\n\26\n","Invalid PNG")
end
for _,d in ipairs(layout.definitions) do
    local path=script_dir.."/../../"..d[1]
    local pipe=assert(io.popen("cksum < "..quote(path),"r"))
    local sum=pipe:read("*a"):match("^(%d+%s+%d+)");pipe:close()
    assert(sum==d[2],"Capture definition changed: "..path)
end
assert(screen:frame_number()<=2,"Load at startup with -autoboot_delay 0")
local function item(tag,name)
    local device=assert(machine.devices[tag],"Missing device "..tag)
    local index=assert(device.items["0/"..name],"Missing saved item "..tag.."/"..name)
    return emu.item(index)
end
local state={
    ctrl=item(":k051316","m_ctrlram"),
    rom_read=item(":k051316","m_readout_enabled"),
    flipx=item(":k051316","m_flipx_enabled"),
    flipy=item(":k051316","m_flipy_enabled"),
    gga=item(":gga","m_regs"),
    gga_index=item(":gga","m_address_latch")
}
local function flag(v) return (v==true or (type(v)=="number" and v~=0)) and 1 or 0 end
local function bytes(n) local b={};for i=1,n do b[i]=0 end;return b end
local registers,gga_index
local function reset_shadow()
    assert(not session.pending,"Reset during capture")
    local prior=registers
    registers={k051316=bytes(16),video=bytes(4),gga=bytes(16)}
    for i=0,13 do registers.k051316[i+1]=state.ctrl:read(i)&255 end
    local old=prior and prior.k051316[15] or 0
    registers.k051316[15]=(old&0xf8)|(1-flag(state.rom_read:read(0)))|
        (flag(state.flipx:read(0))<<1)|(flag(state.flipy:read(0))<<2)
    for i=0,15 do registers.gga[i+1]=state.gga:read(i)&255 end
    gga_index=state.gga_index:read(0)&15
    registers.video[1]=prior and prior.video[1] or 0
    session.control_seen=prior and session.control_seen or false
end
session.reset_subscription=emu.add_machine_reset_notifier(reset_shadow)
reset_shadow()
local function read_ram()
    local result={}
    for _,b in ipairs(layout.ram) do
        local data={}
        if b.stride==2 then
            for i=0,b.bytes-1 do data[#data+1]=string.char(space:read_u8(b.address+i*2)) end
        else
            for i=0,b.bytes-2,2 do data[#data+1]=string.pack(">I2",space:read_u16(b.address+i)) end
        end
        result[#result+1]=table.concat(data)
    end
    return table.concat(result)
end
local function read_mmr()
    for i=0,13 do assert(registers.k051316[i+1]==(state.ctrl:read(i)&255),"PSAC shadow mismatch") end
    for i=0,15 do assert(registers.gga[i+1]==(state.gga:read(i)&255),"GGA shadow mismatch") end
    local ctrl=registers.k051316[15]
    assert((ctrl&1)==1-flag(state.rom_read:read(0)),"PSAC read flag mismatch")
    assert(((ctrl>>1)&1)==flag(state.flipx:read(0)),"PSAC flip-X mismatch")
    assert(((ctrl>>2)&1)==flag(state.flipy:read(0)),"PSAC flip-Y mismatch")
    local result={}
    for _,b in ipairs(layout.mmr) do
        for _,v in ipairs(registers[b.name]) do result[#result+1]=string.char(v) end
    end
    return table.concat(result)
end
session.taps={}
for _,b in ipairs(layout.ram) do
    local lo=b.address&0xfffffe
    local hi=lo+b.bytes*b.stride-1
    session.taps[#session.taps+1]=space:install_write_tap(lo,hi,"ttnose_hold_"..b.name,
        function(a,d,mask)
            if session.pending then
                if b.stride==2 then
                    return session.pending.ram:byte(b.offset+(a-lo)//2+1)
                end
                local high,low=session.pending.ram:byte(b.offset+a-lo+1,b.offset+a-lo+2)
                return (high<<8)|low
            end
            return d
        end)
end
session.taps[#session.taps+1]=space:install_write_tap(0x510000,0x51001f,"ttnose_psac",
    function(a,d,mask)
        if mask&255~=0 then
            local i=(a-0x510000)//2+1
            if session.pending then return registers.k051316[i] end
            registers.k051316[i]=d&255
        end
        return d
    end)
session.taps[#session.taps+1]=space:install_write_tap(0xfff000,0xfff001,"ttnose_gfxbank",
    function(a,d,mask)
        if mask&255~=0 then
            if session.pending then return registers.video[1] end
            registers.video[1]=d&255
            session.control_seen=true
        end
        return d
    end)
session.taps[#session.taps+1]=space:install_write_tap(0xfff020,0xfff023,"ttnose_gga",
    function(a,d,mask)
        if mask&255~=0 then
            if a==0xfff022 then
                if session.pending then return gga_index end
                gga_index=d&15
            else
                if session.pending then return registers.gga[gga_index+1] end
                registers.gga[gga_index+1]=d&255
            end
        end
        return d
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
    if session.pending or session.completion then return false end
    assert(session.control_seen,"Wait for the game to initialize its video-bank latch")
    frame=frame or screen:frame_number()
    local destination=root .. "/scenes/" .. frame
    if exists(destination) and not replace then
        validate_scene(destination)
        print("PRESERVED " .. destination)
        finish_request(frame)
        return false
    end
    serial=serial+1
    local staging=root .. "/scratch/capture/stage-" .. frame .. "-" .. os.time() .. "-" .. serial
    command("mkdir -p " .. quote(staging) .. " " .. quote(root.."/scenes"))
    local was_paused=machine.paused
    local checkpoint=machine:buffer_save()
    session.pending = {
        frame=frame, destination=destination, staging=staging,
        checkpoint=checkpoint, was_paused=was_paused,
        ram=read_ram(), mmr=read_mmr()
    }
    if session.pending.was_paused then emu.unpause() end
    print("HOLD " .. frame)
    return true
end
session.capture = capture

local function publish(pending)
    local expected={["dump.bin"]=true, ["mmr.bin"]=true, ["screen.png"]=true}
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
        assert(read_ram() == pending.ram, "Video RAM changed during held frame")
        assert(read_mmr() == pending.mmr, "Video registers changed during held frame")
        write_file(pending.staging.."/dump.bin", pending.ram)
        write_file(pending.staging.."/mmr.bin", pending.mmr)
        screen:snapshot(pending.staging.."/screen.png")
        validate_scene(pending.staging)
    end, debug.traceback)
    local restored,restore_error=pcall(function()
        assert(machine:buffer_load(pending.checkpoint), "Whole-machine rollback failed")
        assert(screen:frame_number()==pending.frame, "Machine frame did not restore")
        assert(read_ram()==pending.ram, "RAM differs after rollback")
        assert(read_mmr()==pending.mmr, "Registers differ after rollback")
    end)
    session.pending=nil
    if not restored then
        emu.pause()
        error("Capture rollback failed; machine paused: " .. tostring(restore_error))
    end
    emu.pause()
    if not ok then emu.pause(); error(message) end
    publish(pending)
    session.completion=pending
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
    if rising and not scheduled and not session.pending and not session.completion then
        local ok,message=pcall(capture, screen:frame_number())
        if not ok then emu.pause(); print("CAPTURE ERROR " .. tostring(message)) end
    end
end
emu.register_periodic(function()
    local completed=session.completion
    if completed then
        session.completion=nil
        if completed.was_paused then emu.pause() else emu.unpause() end
        session.completed=session.completed+1
        session.last_frame=completed.frame
        session.last_rollback=true
        session.last_was_paused=completed.was_paused
        print("CAPTURED tail2nos "..completed.frame.." rollback=ok")
        finish_request(completed.frame)
    end
    if not scheduled then session.key_event(machine.input:code_pressed(key)) end
end)
_G.jtttnose_scene_capture = session
machine:soft_reset()
