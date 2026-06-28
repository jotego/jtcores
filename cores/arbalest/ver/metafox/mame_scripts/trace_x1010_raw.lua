-- Raw X1-010 write tap: print offs, mask, data verbatim (no interpretation).
local cpu  = manager.machine.devices[":maincpu"]
local mem  = cpu.spaces["program"]
local out  = io.open("x1010_raw.tr","w")
local n = 0
mem:install_write_tap(0x100000, 0x103fff, "x1w", function(offs, data, mask)
    if n < 60 and (data & 0xffff) ~= 0 then
        local pc = cpu.state["PC"].value
        out:write(string.format("offs=%06X mask=%04X data=%04X pc=%06X\n",
            offs, mask & 0xffff, data & 0xffff, pc))
        n = n + 1
    end
end)
emu.add_machine_stop_notifier(function() out:close() end)
