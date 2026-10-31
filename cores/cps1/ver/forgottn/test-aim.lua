-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Date: 31-10-2026

if _G.forgottn_aim_started then return end
_G.forgottn_aim_started = true

local source = debug.getinfo(1, "S").source:sub(2)
local folder = source:match("^(.*)/") or "."
local machine = manager.machine
local cpu = machine.devices[":maincpu"]
local space = cpu.spaces.program
local file = assert(io.open(folder .. "/aim.bin", "rb"))
local code = file:read("a")
file:close()
assert(#code <= 0x200, "aim routine exceeds reserved ROM space")
file = assert(io.open(folder .. "/../../cfg/mame2mra.toml", "r"))
local config = file:read("a")
file:close()
local patches = {}
for address, hex in config:gmatch('{ setname="forgottn", altversion="Right stick", offset=(0x%x+), data="([^"]+)" }') do
    local bytes = {}
    for value in hex:gmatch("%x%x") do bytes[#bytes+1] = tonumber(value,16) end
    assert(#bytes%2 == 0,"MRA patch must contain complete words")
    local decoded = {}
    for k=1,#bytes,2 do decoded[#decoded+1] = string.char(bytes[k+1],bytes[k]) end
    patches[tonumber(address)] = table.concat(decoded)
end
assert(patches[0x100] == code,"MRA patch differs from assembled aim routine")
local hooks = {0x8b38, 0x8ba2, 0xa1dc}
for _, address in ipairs(hooks) do
    assert(space:read_u32(address) == 0xd3680028, "unexpected original ADD instruction")
    assert(space:read_u32(address+4) == 0x30280028, "unexpected original MOVE instruction")
    assert(patches[address] == string.char(0x4e,0xb9,0,0,1,0,0x4e,0x71),"incorrect MRA hook")
end
for k=0, #code-1 do
    assert(space:read_u8(0x100+k) == 0xff, "ROM cave is occupied")
    space:write_direct_u8(0x100+k, code:byte(k+1))
    assert(space:read_u8(0x100+k) == code:byte(k+1), "ROM patch write failed")
end
for address, bytes in pairs(patches) do
    for k=1,#bytes do space:write_direct_u8(address+k-1,bytes:byte(k)) end
end
space:write_direct_u16(0x3f0, 0x60fe)

local cases = {}
for sector=0,31 do
    local radians = sector*math.pi/16
    local x = math.floor(127*math.cos(radians)+0.5)
    local y = math.floor(-127*math.sin(radians)+0.5)
    cases[#cases+1] = {name="sector "..sector, x=x, y=y, player=sector%2, want=sector*64}
end
cases[#cases+1] = {name="center hold", x=0, y=0, initial=0x345, want=0x345}
cases[#cases+1] = {name="deadzone", x=23, y=-23, initial=0x456, want=0x456}
cases[#cases+1] = {name="deadzone boundary", x=24, y=0, want=0}
cases[#cases+1] = {name="negative extremes", x=-128, y=-128, want=0x300}
cases[#cases+1] = {name="signed vertical", x=0, y=-128, want=0x200}
cases[#cases+1] = {name="disabled relative", flag=0x4a54, initial=0x780, delta=64, want=0x7c0}
cases[#cases+1] = {name="old core fallback", flag=0xffff, initial=32, delta=-64, want=0xffe0}

local active, index, frame = nil, 0, 0
local flag, raw1, raw2 = 0, 0, 0
local dial = {0,0}
local taps = {}
_G.forgottn_aim_taps = taps
taps[1] = space:install_read_tap(0x800060,0x800065,"right-stick",function(address)
    if address == 0x800060 then return raw1 end
    if address == 0x800062 then return raw2 end
    if address == 0x800064 then return flag end
end)
taps[2] = space:install_read_tap(0x800052,0x80005d,"dial-count",function(address,data)
    local player = address >= 0x80005a and 2 or 1
    local base = player == 1 and 0x800052 or 0x80005a
    if address == base then return (data&0xff00) | (dial[player]&255) end
    if address == base+2 then return (data&0xfff0) | ((dial[player]>>8)&15) end
end)
taps[3] = space:install_write_tap(0x800040,0x800049,"dial-reset",function(address)
    if address == 0x800040 then dial[1]=0 end
    if address == 0x800048 then dial[2]=0 end
end)

local function launch(test)
    active = test
    flag = test.flag or 0x4a55
    local raw = (((test.y or 0)&255)<<8) | ((test.x or 0)&255)
    raw1 = (test.player or 0) == 0 and raw or 0x7f00
    raw2 = (test.player or 0) ~= 0 and raw or 0x7f00
    cpu.state.SR.value = 0x2700
    cpu.state.A0.value = 0xff7000
    cpu.state.SP.value = 0xff7ff0
    cpu.state.D0.value = 0x1234abcd
    cpu.state.D1.value = (test.delta or 0)&0xffffffff
    for k=2,5 do cpu.state["D"..k].value = 0x32100000+k end
    space:write_u8(0xff701f,test.player or 0)
    space:write_u16(0xff7028,test.initial or 0)
    space:write_u32(0xff7ff0,0x3f0)
    cpu.state.PC.value = 0x100
end

local function button(name, value)
    for _, port in pairs(machine.ioport.ports) do
        for label, field in pairs(port.fields) do
            if label == name then field:set_value(value) end
        end
    end
end

local function step()
    if active then
        if cpu.state.PC.value ~= 0x3f0 and cpu.state.PC.value ~= 0x3f2 then
            print(string.format("FAIL %s: PC=%x SP=%x SR=%x",active.name,cpu.state.PC.value,cpu.state.SP.value,cpu.state.SR.value))
            active = nil
            machine:exit()
            return
        end
        assert(space:read_u16(0xff7028) == active.want, active.name .. ": incorrect aim")
        assert(cpu.state.D0.value == (0x12340000 | active.want), active.name .. ": incorrect D0")
        assert(cpu.state.D1.value == ((active.delta or 0)&0xffffffff), active.name .. ": D1 changed")
        for k=2,5 do assert(cpu.state["D"..k].value == 0x32100000+k, active.name .. ": scratch register changed") end
        assert(cpu.state.A0.value == 0xff7000 and cpu.state.SP.value == 0xff7ff4, active.name .. ": address register/stack changed")
        print("PASS " .. active.name)
        active = nil
    end
    if index < #cases then
        index = index+1
        launch(cases[index])
        return
    elseif frame == 0 then
        space:write_direct_u16(0x3f0,0xffff)
        machine:soft_reset()
        flag,raw1,raw2 = 0x4a55,0x007f,0x8100
    end
    frame = frame+1
    if frame > 500 and frame < 1800 then
        if frame%120 == 0 then button("Coin 1",1) end
        if frame%120 == 10 then button("Coin 1",0) end
        if frame%120 == 30 then button("2 Players Start",1) end
        if frame%120 == 40 then button("2 Players Start",0) end
    end
    if frame == 1800 then raw1,raw2 = 0x8100,0x007f end
    if frame == 1700 then
        button("P1 Button 1",1)
        button("P2 Button 1",1)
    end
    if frame == 1900 then
        assert(space:read_u8(0xffb342) ~= 0 and space:read_u8(0xffb392) ~= 0,"both players must be active")
        assert(space:read_u16(0xffb36a) == 0x200,"P1 gameplay aim")
        assert(space:read_u16(0xffb3ba) == 0,"P2 gameplay aim")
        raw1,raw2 = 0,0
    end
    if frame == 1950 then
        assert(space:read_u16(0xffb36a) == 0x200,"P1 centered stick must hold")
        assert(space:read_u16(0xffb3ba) == 0,"P2 centered stick must hold")
        flag,dial[1] = 0x4a54,64
    end
    if frame == 2000 then
        assert(space:read_u16(0xffb36a) == 0x240,"switching to dial must restore relative rotation")
        assert(space:read_u16(0xffb3ba) == 0,"P1 dial must not affect P2")
        print("PASS patched boot, two-player aiming, neutral hold and dial switch")
        machine:exit()
    end
end

emu.register_frame_done(function()
    local ok, message = pcall(step)
    if not ok then
        print("FAIL " .. message)
        machine:exit()
    end
end,"frame")
