-- SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Current MAME: avengers -autoboot_script capture.lua -seconds_to_run 35
-- Output: trace.log, for simunit.sh with MCU_TRACE and MCU_ROM set.
local file = assert(io.open('trace.log', 'w'))
local function log(kind, address, data)
    file:write(string.format('%.9f %s %04x %02x\n',
        manager.machine.time:as_double(), kind, address, data))
end
-- Retain tap handles until the machine stops.
avengers_taps = {}
local main = manager.machine.devices[':maincpu'].spaces['program']
local sfr = manager.machine.devices[':mcu'].spaces['sfr']
avengers_taps[1] = main:install_write_tap(0xf809, 0xf809, 'mcu_request',
    function(a, d) log('W', a, d) end)
avengers_taps[2] = main:install_write_tap(0xf80c, 0xf80c, 'sound_request',
    function(a, d) log('S', a, d) end)
avengers_taps[3] = main:install_read_tap(0xf80d, 0xf80d, 'mcu_response',
    function(a, d) log('R', a, d) end)
local function port(address)
    return address == 0x80 or address == 0x90 or address == 0xa0 or address == 0xb0
end
avengers_taps[4] = sfr:install_read_tap(0x80, 0xff, 'mcu_ports_in',
    function(a, d) if port(a) then log('I', a, d) end end)
avengers_taps[5] = sfr:install_write_tap(0x80, 0xff, 'mcu_ports_out',
    function(a, d) if port(a) then log('O', a, d) end end)
local frame = 0
emu.register_frame_done(function()
    frame = frame + 1
    for _, tap in pairs(avengers_taps) do tap:reinstall() end
    for _, input in pairs(manager.machine.ioport.ports[':SERVICE'].fields) do
        if input.name == 'Coin 1' then
            input:set_value(frame >= 900 and frame < 905 and 1 or 0)
        elseif input.name == '1 Player Start' then
            input:set_value(frame >= 960 and frame < 965 and 1 or 0)
        end
    end
end)
avengers_stop = emu.add_machine_stop_notifier(function() file:close() end)
