-- Does F-1 Grand Prix flip its ROZ layer in software?
--
-- MAME latches gfxctrl bit 5 into m_flipscreen and never reads it back, and the
-- driver is MACHINE_NO_COCKTAIL, so MAME cannot answer this. But the game code
-- reads the Flip Screen DIP either way and writes the K053936 control registers
-- from it, so the register file is observable even though nothing renders it.
--
-- The game samples the DIPs at boot, before an autoboot script can run, so the
-- switch must be set through MAME's cfg file rather than from Lua:
--   <port tag=":DSW2" type="DIPSWITCH" mask="512" defvalue="512" value="0" />
-- Run twice, with and without that override, and diff the two outputs.
--   registers differ  -> the game flips the road itself, jt053936 needs nothing
--   registers equal   -> the chip or the board does it, jt053936 needs a flip input
local FLIP  = tonumber(os.getenv("F1GP_FLIP") or "0")
local UNTIL = tonumber(os.getenv("F1GP_FRAME") or "1500")

local screen; for _,s in pairs(manager.machine.screens) do screen=s; break end
local mem = manager.machine.devices[":maincpu"].spaces["program"]

local roz = {}; for i=0,15 do roz[i]=0 end
local gfxctrl = 0
roz_tap = mem:install_write_tap(0xfff040, 0xfff05f, "roz",
  function(offset, data, mask)
    local idx = (offset - 0xfff040) >> 1
    if idx>=0 and idx<=15 then roz[idx] = data & 0xffff end
  end)
ctl_tap = mem:install_write_tap(0xfff000, 0xfff001, "gfxctrl",
  function(offset, data, mask)
    if (mask & 0x00ff) ~= 0 then gfxctrl = data & 0xff end
  end)

emu.register_frame_done(function()
  if screen:frame_number() >= UNTIL then
    local r = {}
    for i=0,15 do r[#r+1] = string.format("%04x", roz[i]) end
    print(string.format("FLIP=%d frame=%d gfxctrl=%02x", FLIP, UNTIL, gfxctrl))
    print("ROZ "..table.concat(r," "))
    manager.machine:exit()
  end
end)
