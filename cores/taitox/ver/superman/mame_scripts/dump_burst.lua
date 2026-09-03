-- Taito X burst scene dump: 20 scenes, 300 frames apart.
--
-- Writes dump.bin in the order cores/taitox/ver/game/dump2bin.sh splits it,
-- which is the mem.yaml ioctl save order, and in the byte order the BRAM
-- SIMFILE loaders expect (ENDIAN=0 -> low byte first). MAME's read_u8 walks
-- ascending 68k addresses, i.e. big-endian, so the 16-bit regions are swapped
-- here.
--   pal   b00000  512 words -> 1 kB   X1-006 only sees A9..A1
--   yram  d00000 1024 bytes -> 1 kB   8-bit device on the low lane:
--                                     d00000-d005ff sprite Y, d00600 ctrl
--   dma   e00000 8192 words -> 16 kB  OBJ RAM, both setac buffers
--   rest  d00600    4 bytes          X1-001 cfg registers. These are flops in
--                                    jtkiwi_gfx, not a BRAM, so rest2bin.sh
--                                    turns them into seta_cfg.hex. Without
--                                    them the background layer stays blank.
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local screen; for _,s in pairs(manager.machine.screens) do screen=s; break end

local targets = {}
for i=1,20 do targets[i] = i*300 end
local idx = 1

local function put16(f, base, words)   -- big-endian source -> little-endian file
  for w = 0, words-1 do
    f:write(string.char(mem:read_u8(base+2*w+1)))
    f:write(string.char(mem:read_u8(base+2*w  )))
  end
end

local function put8lo(f, base, bytes)  -- 8-bit device sitting on the low lane
  for i = 0, bytes-1 do f:write(string.char(mem:read_u8(base+2*i+1))) end
end

local function capture(frame)
  local dir = string.format("/tmp/taitox_burst_%05d", frame)
  os.execute("mkdir -p '"..dir.."'")
  local f = io.open(dir.."/dump.bin", "wb")
  put16 (f, 0xb00000,  512)
  put8lo(f, 0xd00000, 1024)
  put16 (f, 0xe00000, 8192)
  put8lo(f, 0xd00600,    4)
  f:close()
  screen:snapshot(dir.."/screen.png")
  print(string.format("SCENE %05d dumped", frame))
end

emu.register_frame_done(function()
  if idx <= #targets and screen:frame_number() >= targets[idx] then
    capture(targets[idx]); idx = idx + 1
    if idx > #targets then manager.machine:exit() end
  end
end)
