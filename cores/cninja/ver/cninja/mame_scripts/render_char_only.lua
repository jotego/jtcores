local mac = manager.machine
local prog = mac.devices[":maincpu"].spaces["program"]
local scr = mac.screens:at(1)
prog:install_write_tap(0x146000,0x147fff,"za",function() return 0 end)
prog:install_write_tap(0x154000,0x157fff,"zb",function() return 0 end)
prog:install_write_tap(0x1a4000,0x1a47ff,"zc",function() return 0 end)
local done=false
_G.__c = emu.add_machine_frame_notifier(function()
  if done then return end
  local nz=0
  for a=0x144000,0x144ffe,2 do if prog:read_u16(a)~=0 then nz=nz+1; if nz>20 then break end end end
  if nz>20 then
    done=true
    scr:snapshot("/tmp/cnj_mame_charonly.png")
    emu.print_info("charonly snapped at fn="..scr:frame_number())
  end
end)
