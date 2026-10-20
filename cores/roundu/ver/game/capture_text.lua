-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Date: 19-10-2026

local m=manager.machine
local root=m.devices[":"]
local screen=m.screens[":screen"]
local mem=m.devices[":maincpu"].spaces.program
local sub=m.devices[":sub"].spaces.program
local out=assert(os.getenv("ROUNDU_CAPTURE"))
local testmode=os.getenv("ROUNDU_TEST")=="1"
local target=tonumber(os.getenv("ROUNDU_CAPTURE_FRAME") or "600")
local gfx=emu.item(assert(root.items["0/m_tx_gfxram"]))
local crtc,index,control={},0,0
local taps={}
local frozen=nil
for i=0,63 do crtc[i]=0 end
for _,port in pairs(m.ioport.ports) do
    for name,field in pairs(port.fields) do
        if name=="Hardware Test Mode" then field.user_value=testmode and 0 or 0x8000 end
        if name=="Service Mode" or name=="Test Mode" then field.user_value=0 end
    end
end
taps[#taps+1]=mem:install_write_tap(0xc000,0xc003,"crtc_shadow",function(a,d,mask)
    if frozen then return a==0xc000 and index or crtc[index] end
    if (mask&0xff)~=0 then
        if a==0xc000 then index=d&0x3f else crtc[index]=d&0xff end
    end
end)
taps[#taps+1]=mem:install_write_tap(0xe000,0xe001,"control_shadow",function(a,d,mask)
    if frozen then return control end
    control=(control&(~mask))|(d&mask)
end)
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
    return blocks
end
local function hold(space,lo,hi,name,reader)
    taps[#taps+1]=space:install_write_tap(lo,hi,name,function(a) return reader(a) end)
end
roundu_capture_notifier=emu.add_machine_frame_notifier(function()
    local frame=screen:frame_number()
    if not frozen and frame>=target then
        assert(frame==target,"Missed capture frame")
        frozen=read_state()
        local f=assert(io.open(out.."/dump.bin","wb"))
        local size=0
        for _,block in ipairs(frozen) do f:write(block);size=size+#block end
        f:close()
        assert(size==149568,"Wrong diagnostic dump size")
        hold(mem,0x8000,0xbfff,"hold_text",function(a) return mem:read_u16(a) end)
        hold(mem,0xf000,0xffff,"hold_palette",function(a) return mem:read_u16(a) end)
        hold(mem,0x30000,0x3ffff,"hold_graphics",function(a) return mem:read_u16(a) end)
        hold(mem,0xe000,0xe001,"hold_control",function() return control end)
        hold(mem,0xc000,0xc003,"hold_crtc",function(a) return a==0xc000 and index or crtc[index] end)
        for _,r in ipairs({{0xd400,0xd40f,"vregs"},{0xd800,0xd801,"bg_scrollx"},{0xdc00,0xdc01,"bg_scrolly"}}) do
            local share=assert(m.memory.shares[":"..r[3]])
            local base=r[1]
            hold(mem,r[1],r[2],"hold_"..r[3],function(a) return share:read_u16(a-base) end)
        end
        for _,r in ipairs({{0x90000,0x93fff},{0x9a000,0x9a1ff},{0xa0000,0xa0fff},{0xb0000,0xb0fff},{0xc0000,0xc0fff},{0xd0000,0xd0001},{0xe0000,0xe0001}}) do
            hold(sub,r[1],r[2],"hold_sub_"..r[1],function(a) return sub:read_u16(a) end)
        end
        print("TEXT_DUMP_OK frame="..frame.." bytes="..size)
    elseif frozen then
        assert(frame==target+1,"Unexpected reference boundary")
        local current=read_state()
        for i=1,4 do assert(current[i]==frozen[i],"Held text state changed") end
        assert(not screen:snapshot(out.."/screen.png"),"Snapshot failed")
        print("TEXT_REFERENCE_OK frame="..frame.." text_state_held=1 testmode="..tostring(testmode))
        m:exit()
    end
end)
