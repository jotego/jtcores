local mac=manager.machine; local scr=mac.screens:at(1)
local pin=mac.ioport.ports[":INPUTS"]; local psys=mac.ioport.ports[":SYSTEM"]
local f=io.open("/tmp/cnj_boss/perframe.txt","w")
_G.__pf=emu.add_machine_frame_notifier(function()
  local fn=scr:frame_number()
  if fn>2800 then return end
  f:write(string.format("%d %04x %04x\n",fn,pin:read(),psys:read()))
end)
