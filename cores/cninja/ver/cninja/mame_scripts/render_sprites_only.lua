local mac=manager.machine
local prog=mac.devices[":maincpu"].spaces["program"]
local scr=mac.screens:at(1)
-- keep ONLY sprites: zero all 4 tilemaps
prog:install_write_tap(0x144000,0x147fff,"za",function() return 0 end)
prog:install_write_tap(0x154000,0x157fff,"zb",function() return 0 end)
local done=false
_G.__s=emu.add_machine_frame_notifier(function()
  if scr:frame_number()<1500 or done then return end
  done=true
  scr:snapshot("/tmp/cnj_spronly.png")
  local f=io.open("/tmp/cnj_spr.bin","wb")
  for i=0,0x7ff do f:write(string.char(prog:read_u8(0x1a4000+i))) end
  f:close()
  emu.print_info("sprites-only snapped + spriteram dumped at fn="..scr:frame_number())
end)
