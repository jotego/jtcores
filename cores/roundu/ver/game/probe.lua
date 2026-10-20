-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Date: 19-10-2026

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local count = 0
local frame = 0
local taps = {}
taps[1] = mem:install_write_tap(0xe000, 0xe001, "control_probe", function(off, data, mask)
    count = count + 1
    if count < 128 then
        print(string.format("CONTROL frame=%d pc=%05x data=%04x mask=%04x", frame, cpu.state["PC"].value, data, mask))
    end
end)
emu.register_frame_done(function()
    frame = frame + 1
    if frame == 30 or frame == 90 or frame == 180 or frame == 360 or frame == 600 then
        manager.machine.screens[":screen"]:snapshot(string.format("mame-boot-%05d.png", frame))
    end
    if frame == 180 or frame == 600 then
        local nonzero = 0
        for address = 0x8000, 0xbffe, 2 do
            if mem:read_u16(address) ~= 0 then nonzero = nonzero + 1 end
        end
        print(string.format("TEXT_WORDS frame=%d nonzero=%d", frame, nonzero))
    end
    if frame % 30 == 0 then
        print(string.format("FRAME %d PC=%05x SUB=%06x Z80=%04x TEXT=%04x", frame,
            cpu.state["PC"].value, manager.machine.devices[":sub"].state["PC"].value,
            manager.machine.devices[":audiocpu"].state["PC"].value, mem:read_u16(0x8000)))
    end
end)
