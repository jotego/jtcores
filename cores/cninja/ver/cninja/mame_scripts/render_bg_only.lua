local mac = manager.machine
local prog = mac.devices[":maincpu"].spaces["program"]
local scr = mac.screens:at(1)
-- force overlay layers + sprites to stay blank (write 0)
prog:install_write_tap(0x144000,0x147fff,"z0",function(o,d,m) return 0 end)  -- tilegen0 pf1+pf2
prog:install_write_tap(0x154000,0x155fff,"z1",function(o,d,m) return 0 end)  -- tilegen1 pf1
prog:install_write_tap(0x1a4000,0x1a47ff,"z2",function(o,d,m) return 0 end)  -- sprite RAM
local done=false
_G.__b = emu.add_machine_frame_notifier(function()
  if scr:frame_number()>=320 and not done then
    done=true; scr:snapshot("/tmp/cnj_mame_bgonly.png"); emu.print_info("snap bg-only fn="..scr:frame_number())
  end
end)
