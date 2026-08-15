-- Taito X burst scene dump: 20 scenes, 300 frames apart (5s..100s @ ~57.4Hz).
-- Regions are the CPU-visible views of the X1-001/X1-002/X1-006 RAMs, byte
-- order as the 68000 sees them (big-endian). The FPGA SIMFILE loader must
-- byte-swap to FPGA-native order.
--   pal   b00000 0x1000  palette, only the low 0x400 is real (X1-006 sees A9..A1)
--   yram  d00000 0x0600  spriteylow: 0x000-0x2ff Y, 0x200-0x2ff BG column scroll
--   ctrl  d00600 0x0008  the four spritectrl words
--   oram  e00000 0x4000  OBJ RAM, both setac buffers
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local screen; for _,s in pairs(manager.machine.screens) do screen=s; break end

local targets = {}
for i=1,20 do targets[i] = i*300 end
local idx = 1

local regions = {
  { name="pal.bin",  start=0xb00000, len=0x1000 },
  { name="yram.bin", start=0xd00000, len=0x0600 },
  { name="ctrl.bin", start=0xd00600, len=0x0008 },
  { name="oram.bin", start=0xe00000, len=0x4000 },
}

local function capture(frame)
  local dir = string.format("/tmp/taitox_burst_%05d", frame)
  os.execute("mkdir -p '"..dir.."'")
  for _,r in ipairs(regions) do
    local f = io.open(dir.."/"..r.name, "wb")
    for a = r.start, r.start+r.len-1 do f:write(string.char(mem:read_u8(a, false))) end
    f:close()
  end
  manager.machine.video:snapshot()
  print(string.format("SCENE %05d dumped", frame))
end

emu.register_frame_done(function()
  if idx <= #targets and screen:frame_number() >= targets[idx] then
    capture(targets[idx]); idx = idx + 1
    if idx > #targets then manager.machine:exit() end
  end
end)
