-- Trace X1-010 accesses on the 68000 main bus for metafox, RAW byte address.
local cpu  = manager.machine.devices[":maincpu"]
local mem  = cpu.spaces["program"]
local out  = io.open("x1010_mame.tr","w")
out:write("# X1-010 raw access trace (metafox). addr=byte addr, lane from mask\n")

local BASE = 0x100000
local TOP  = 0x103fff
local nwr, nrd = 0, 0

mem:install_write_tap(BASE, TOP, "x1w", function(offs, data, mask)
    local lane, byte
    if (mask & 0xff00) ~= 0 and (mask & 0x00ff) ~= 0 then
        lane = "W16"; byte = data & 0xffff
    elseif (mask & 0xff00) ~= 0 then
        lane = "Hi";  byte = (data >> 8) & 0xff   -- even byte addr (UDS / D15:8)
    else
        lane = "Lo";  byte = data & 0xff          -- odd byte addr (LDS / D7:0)
    end
    if byte ~= 0 then
        out:write(string.format("W addr=%06X %s val=%02X\n", offs, lane, byte))
    end
    nwr = nwr + 1
end)

mem:install_read_tap(BASE, TOP, "x1r", function(offs, data, mask)
    out:write(string.format("R addr=%06X mask=%04X data=%04X\n", offs, mask & 0xffff, data & 0xffff))
    nrd = nrd + 1
end)

emu.add_machine_stop_notifier(function()
    out:write(string.format("# writes=%d reads=%d\n", nwr, nrd))
    out:close()
end)
