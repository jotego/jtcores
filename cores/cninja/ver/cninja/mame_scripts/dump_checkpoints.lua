local mac = manager.machine
local scr = mac.screens:at(1)
local targets = {}
for f=300,3000,300 do targets[#targets+1]=f end
local done = {}
_G.__cp = emu.add_machine_frame_notifier(function()
  local fn = scr:frame_number()
  for _,t in ipairs(targets) do
    if fn>=t and not done[t] then
      done[t]=true
      scr:snapshot(string.format("/tmp/cnj_ref/%04d.png", t))
      emu.print_info("CHECKPOINT "..t.." at fn="..fn)
    end
  end
end)
emu.print_info("checkpoints installed (300..3000 step 300)")
