-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Date: 20-10-2026

local m=manager.machine
local cpu=m.devices[":maincpu"]
local mem=cpu.spaces.program
local snd=m.devices[":audiocpu"].spaces.program
local screen=m.screens[":screen"]
local start=nil
local fm,pcm=0,0
local taps={}
for tag,port in pairs(m.ioport.ports) do
    for name,field in pairs(port.fields) do
        if tag==":IN0" and field.mask==0x20 then start=field end
        if name=="Hardware Test Mode" then field.user_value=0x8000 end
    end
end
taps[#taps+1]=mem:install_write_tap(0x5152,0x515b,"credit_probe",function(a,d,mask)
    print(string.format("CREDIT frame=%d addr=%04x data=%04x mask=%04x",screen:frame_number(),a,d,mask))
end)
taps[#taps+1]=snd:install_write_tap(0xfff0,0xfff4,"sound_probe",function(a,d,mask)
    if a<=0xfff1 then fm=fm+1 elseif a==0xfff4 then pcm=pcm+1 end
end)
roundu_probe_notifier=emu.add_machine_frame_notifier(function()
    assert(#taps==2)
    local frame=screen:frame_number()
    if frame==700 then assert(start); start:set_value(1); print("PROBE_INPUT frame=700 start=1") end
    if frame==710 then start:set_value(0); print("PROBE_INPUT frame=710 start=0") end
    if frame%100==0 then
        print(string.format("PROBE frame=%d credits=%04x coinA=%04x coinB=%04x fm=%d pcm=%d",frame,
            mem:read_u16(0x5152),mem:read_u16(0x5156),mem:read_u16(0x515a),fm,pcm))
    end
    if frame==1500 then m:exit() end
end)
