-- Capture 20 pspikes scenes, 300 frames apart, in ONE MAME run.
--
-- Each scene directory gets the per-region .bin files the FPGA scene replay
-- loads (see ver/game/sim.sh) plus MAME's screen.png reference.
--
-- The RAMs are read from the memory SHARES, not through the CPU address
-- space: 0xffc000 sprite RAM is mapped writeonly(), so mem:read_u8() on it
-- returns 0 and the sprite list looks empty.
--
-- read_u8 walks ascending addresses, so the files are big endian (68000
-- order). mem.yaml declares the BRAM simfiles big_endian so they load as is.
local shares = manager.machine.memory.shares
local screen; for _,s in pairs(manager.machine.screens) do screen=s; break end

local SCENES, STEP = 20, 300
local OUT = os.getenv("PSPIKE_SCENES") or "cores/pspike/ver/powerspikes/scenes"

-- order matters, see capture() below
local regions = {
  { name = "vram",  tag = ":vram.0"        },  --  4 kB tilemap
  { name = "rascr", tag = ":rasterram"     },  --  4 kB, per line scroll X
  { name = "oram",  tag = ":spriteram"     },  --  1 kB, 128 slots x 4 words
  { name = "lut",   tag = ":sprlookupram1" },  -- 16 kB, sprite tile lookup
  { name = "pal",   tag = ":palette"       },  --  4 kB
}

local idx = 1

-- The video configuration lives in 68000 registers, not RAM, so a scene
-- replay with NOMAIN would render with all of them zero. Track the writes.
--   fff001 palette bank: [1:0] sprite bank, [4:2] char bank, [7] flip
--   fff003 gfx bank:     [7:4] bank 0, [3:0] bank 1
--   fff004 scroll Y (word)
local palbank, gfxbank, scrolly = 0, 0, 0
local mem = manager.machine.devices[":maincpu"].spaces["program"]
-- keep the handle alive: a garbage collected tap segfaults mid run
vregs_tap = mem:install_write_tap(0xfff000, 0xfff007, "vregs",
  function(offset, data, mask)
    if offset == 0xfff000 and (mask & 0x00ff) ~= 0 then palbank = data & 0xff end
    if offset == 0xfff002 and (mask & 0x00ff) ~= 0 then gfxbank = data & 0xff end
    if offset == 0xfff004 then scrolly = data & 0x1ff end
  end)

-- jtsim -s <dir> loads <dir>/dump.bin and splits it with ver/game/rest2bin.sh,
-- so everything goes into one file. The order here MUST match that script:
--   vram 4096, rascr 4096, oram 1024, lut 16384, pal 4096, regs 4 = 29700
local function capture(frame)
  local dir = string.format("%s/m%05d", OUT, frame)
  os.execute("mkdir -p '"..dir.."'")
  local f = io.open(dir.."/dump.bin","wb")
  for _,r in ipairs(regions) do
    local sh = shares[r.tag]
    for a = 0, sh.size-1 do f:write(string.char(sh:read_u8(a))) end
  end
  f:write(string.char(palbank, gfxbank, (scrolly >> 8) & 0xff, scrolly & 0xff))
  f:close()
  manager.machine.video:snapshot()
  print(string.format("scene m%05d  palbank=%02x gfxbank=%02x scrolly=%03x",
        frame, palbank, gfxbank, scrolly))
end

emu.register_frame_done(function()
  local target = idx*STEP
  if idx <= SCENES and screen:frame_number() >= target then
    capture(target); idx = idx + 1
    if idx > SCENES then manager.machine:exit() end
  end
end)
