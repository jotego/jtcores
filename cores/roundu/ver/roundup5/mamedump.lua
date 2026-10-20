-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Date: 20-10-2026

assert(not mamedump, "mamedump.lua is already loaded")
assert(emu.app_version() == "0.282", "Use MAME 0.282 for this capture binding")
local lfs = require("lfs")
local m = manager.machine
assert(m.system.name == "roundup5", "This dump script is for roundup5")
local source = debug.getinfo(1, "S").source:gsub("^@", "")
local base = source:match("^(.*)/") or "."
local output = os.getenv("MAMEDUMP_OUTPUT") or base.."/scenes"
local work = os.getenv("MAMEDUMP_WORK") or base.."/scratch/mamedump"
local target = tonumber(os.getenv("MAMEDUMP_FRAME") or "")
local autoplay = target ~= nil and os.getenv("MAMEDUMP_AUTOPLAY") ~= "0"
local replace = os.getenv("MAMEDUMP_REPLACE") == "1"
local screen = assert(m.screens[":screen"])
assert(screen:frame_number() <= 1, "Load mamedump.lua at MAME startup to track write-only CRTC registers")
local root = m.devices[":"]
local mem = m.devices[":maincpu"].spaces.program
local sub = m.devices[":sub"].spaces.program
local gfx = emu.item(assert(root.items["0/m_tx_gfxram"]))
local bg = emu.item(assert(root.items["0/m_bg_gfxram"]))
local crtc, index, control = {}, 0, 0
local observers, pending = {}, nil
local held, requested, fatal = false, false, false
local startfield, accelerator
local key = m.input:seq_from_tokens("KEYCODE_BACKSLASH")
mamedump = { observers = observers }
for i=0,63 do crtc[i]=0 end

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
for portname,port in pairs(m.ioport.ports) do
    for name,field in pairs(port.fields) do
        if portname==":IN0" and field.mask==0x20 then startfield=field end
        if portname==":IN0" and field.mask==0x01 then accelerator=field end
        if autoplay and name=="Hardware Test Mode" then field.user_value=0x8000 end
        if autoplay and (name=="Service Mode" or name=="Test Mode") then field.user_value=0 end
    end
end
observers[#observers+1] = mem:install_write_tap(0xc000,0xc003,"dump_crtc",function(a,d,mask)
    if pending then return a==0xc000 and index or crtc[index] end
    if (mask&0xff)~=0 then
        if a==0xc000 then index=d&0x3f else crtc[index]=d&0xff end
    end
end)
observers[#observers+1] = mem:install_write_tap(0xe000,0xe001,"dump_control",function(a,d,mask)
    if pending then return control end
    control=(control&(~mask))|(d&mask)
end)

local mmr_layout = {
    { name="crtc", size=64, seek=0, blocks={4}, padding=0, restore="jtroundu_crtc_mmr" },
    { name="main", size=32, seek=64, blocks={13}, padding=10, restore="jtroundu_main_mmr" },
    { name="road", size=4, seek=96, blocks={11,12}, padding=0, restore="jtroundu_road_mmr" },
    { name="object", size=512, seek=100, blocks={7}, padding=0, restore="jtroundu_object_mmr" },
}
mamedump.mmr_layout = mmr_layout

local function read_state()
    local blocks={}
    local b={}
    for a=0x8000,0xbffe,2 do b[#b+1]=string.pack("<I2",mem:read_u16(a)) end
    blocks[1]=table.concat(b)
    b={}
    for i=0,0x1ffff do b[#b+1]=string.char(gfx:read(i)) end
    blocks[2]=table.concat(b)
    b={}
    for i=0,1023 do
        local hi=mem:read_u8(0xf000+i*4)
        local lo=mem:read_u8(0xf002+i*4)
        b[#b+1]=string.char(lo,hi)
    end
    blocks[3]=table.concat(b)
    b={}
    for i=0,63 do b[#b+1]=string.char(crtc[i]) end
    blocks[4]=table.concat(b)
    b={}
    for i=0,0x1ffff do b[#b+1]=string.char(bg:read(i)) end
    blocks[5]=table.concat(b)
    for n,r in ipairs({{0x90000,0x4000},{0x9a000,0x200},{0xa0000,0x1000},{0xb0000,0x1000},{0xc0000,0x1000},{0xd0000,2},{0xe0000,2}}) do
        b={}
        for a=r[1],r[1]+r[2]-2,2 do b[#b+1]=string.pack("<I2",sub:read_u16(a)) end
        blocks[5+n]=table.concat(b)
    end
    b={string.pack("<I2",control)}
    for _,name in ipairs({"vregs","bg_scrollx","bg_scrolly"}) do
        local share=assert(m.memory.shares[":"..name])
        local size=name=="vregs" and 16 or 2
        for a=0,size-2,2 do b[#b+1]=string.pack("<I2",share:read_u16(a)) end
    end
    blocks[13]=table.concat(b)
    return blocks
end

local function hold(space, lo, hi, name, reader)
    pending.taps[#pending.taps+1] = space:install_write_tap(lo,hi,name,function(a) return reader(a) end)
end
local function freeze()
    hold(mem,0x8000,0xbfff,"dump_text",function(a) return mem:read_u16(a) end)
    hold(mem,0xf000,0xffff,"dump_palette",function(a) return mem:read_u16(a) end)
    hold(mem,0x30000,0x3ffff,"dump_graphics",function(a) return mem:read_u16(a) end)
    for _,r in ipairs({{0xd400,0xd40f,"vregs"},{0xd800,0xd801,"bg_scrollx"},{0xdc00,0xdc01,"bg_scrolly"}}) do
        local share=assert(m.memory.shares[":"..r[3]])
        local address=r[1]
        hold(mem,r[1],r[2],"dump_"..r[3],function(a) return share:read_u16(a-address) end)
    end
    for _,r in ipairs({{0x90000,0x93fff},{0x9a000,0x9a1ff},{0xa0000,0xa0fff},{0xb0000,0xb0fff},{0xc0000,0xc0fff},{0xd0000,0xd0001},{0xe0000,0xe0001}}) do
        hold(sub,r[1],r[2],"dump_sub_"..r[1],function(a) return sub:read_u16(a) end)
    end
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
    local dump=table.concat(p.blocks)
    assert(#dump==309850, "Unexpected video dump size")
    write(p.path.."/dump.bin",dump)
    local mmr={}
    local offset=0
    for _,entry in ipairs(mmr_layout) do
        local raw={}
        for _,number in ipairs(entry.blocks) do raw[#raw+1]=p.blocks[number] end
        raw=table.concat(raw)..string.rep("\0",entry.padding)
        assert(#raw==entry.size and offset==entry.seek, "MMR restore layout mismatch: "..entry.name)
        mmr[#mmr+1]=raw
        offset=offset+#raw
    end
    write(p.path.."/mmr.bin",table.concat(mmr))
    freeze()
    requested=false
    if p.paused then emu.unpause() end
end
local function finish_capture()
    local p=assert(pending)
    local frame=screen:frame_number()
    if frame==p.frame then return end
    assert(frame==p.frame+1, "Missed held reference frame")
    local current=read_state()
    for i,bytes in ipairs(p.blocks) do assert(current[i]==bytes, "Held video changed at block "..i) end
    assert(not screen:snapshot(p.path.."/screen.png"), "Snapshot failed")
    if target then unfreeze(p) else restore(p) end
    if lfs.attributes(p.destination) then
        local serial=0
        local backup
        repeat
            backup=work.."/"..p.frame..".previous-"..serial
            serial=serial+1
        until not lfs.attributes(backup)
        assert(os.rename(p.destination,backup))
    end
    assert(os.rename(p.path,p.destination))
    pending=nil
    mamedump.last_frame=p.frame
    log("MAMEDUMP_OK frame="..p.frame.." reference="..frame.." bytes=309850 mmr=612 resumed="..tostring(not target))
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
        if autoplay then
            if frame==700 then assert(startfield):set_value(1) end
            if frame==710 then assert(startfield):set_value(0) end
            if frame==800 then assert(accelerator):set_value(1) end
        end
        if target and frame>=target then
            assert(frame==target, "Missed requested frame")
            begin_capture()
        elseif requested then begin_capture() end
    end)
    if not ok then fail(err) end
end)
log("MAMEDUMP_READY game=roundup5 mame="..emu.app_version().." mode="..(target and "frame" or "keypress"))
if not target then m:popmessage("Capture scene: backslash (\\)") end
