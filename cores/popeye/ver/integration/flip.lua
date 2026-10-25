local io=manager.machine.devices[':maincpu'].spaces['io']
local frame=0
local address=0
local addr_tap=io:install_write_tap(0,0,'scene_ay_address',function(a,data,mask) address=data&15 end)
local flip_tap=io:install_write_tap(1,1,'scene_flip',function(a,data,mask)
 if frame>=2100 and address==15 then return data|1 end
end)
emu.register_frame_done(function()
 frame=frame+1
 if frame==2100 then io:write_u8(0,15);io:write_u8(1,1) end
 if frame>=2400 then manager.machine:exit() end
end,'flip scenes')
