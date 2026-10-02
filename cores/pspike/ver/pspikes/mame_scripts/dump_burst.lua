-- Dump the pspikes video RAMs at a few attract-mode frames.
--
-- These are read from the memory SHARES, not through the CPU address space:
-- 0xffc000 sprite RAM is mapped writeonly(), so mem:read_u8() on it returns 0
-- and the dump looks like an empty sprite list.
local shares = manager.machine.memory.shares
local screen; for _,s in pairs(manager.machine.screens) do screen=s; break end

local targets = {300,600,900,1050,1200}
local idx = 1

local regions = {
  { name = "oram",  tag = ":spriteram"     },  -- 1 kB, 128 slots x 4 words
  { name = "lut",   tag = ":sprlookupram1" },  -- 16 kB, sprite tile lookup
  { name = "pal",   tag = ":palette"       },  -- 4 kB
  { name = "vram",  tag = ":vram.0"        },  -- 4 kB tilemap
  { name = "rascr", tag = ":rasterram"     },  -- 4 kB, per line scroll X
}

local function capture(frame)
  local dir = string.format("/tmp/pspike_burst_%05d", frame)
  os.execute("mkdir -p '"..dir.."'")
  for _,r in ipairs(regions) do
    local sh = shares[r.tag]
    local f = io.open(dir.."/"..r.name..".bin","wb")
    for a = 0, sh.size-1 do f:write(string.char(sh:read_u8(a))) end
    f:close()
  end
  manager.machine.video:snapshot()
  print(string.format("dumped frame %d", frame))
end

emu.register_frame_done(function()
  if idx <= #targets and screen:frame_number() >= targets[idx] then
    capture(targets[idx]); idx = idx + 1
    if idx > #targets then manager.machine:exit() end
  end
end)
