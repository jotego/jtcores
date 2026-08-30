-- Capture 20 Turbo Force scenes, 300 frames apart, in ONE MAME run.
--
-- Turbo Force shows nothing before about frame 1800, so the earliest scenes
-- are boot screens on purpose - they still exercise the tile layers.
--
-- Read from the memory SHARES, not the CPU space: the sprite RAM region is
-- write only on some sets and reads back as zero through mem:read_u8.
--
-- read_u8 walks ascending addresses, so the file is big endian (68000 order);
-- mem.yaml declares the BRAM simfiles big_endian to match.
local shares = manager.machine.memory.shares
local screen; for _,s in pairs(manager.machine.screens) do screen=s; break end

local SCENES, STEP = 20, 300
local OUT = os.getenv("TF_SCENES") or "cores/pspike/ver/turbofrc/scenes"

-- Order must match ver/game/rest2bin.sh
--   vram0 8192, vram1 8192, rascr 4096, oram 2048,
--   lut0 16384, lut1 16384, pal 2048, regs 8   = 57352
local regions = {
  { name = "vram0", tag = ":vram.0"        },
  { name = "vram1", tag = ":vram.1"        },
  { name = "rascr", tag = ":rasterram"     },
  { name = "oram",  tag = ":spriteram"     },
  { name = "lut0",  tag = ":sprlookupram1" },
  { name = "lut1",  tag = ":sprlookupram2" },
  { name = "pal",   tag = ":palette"       },
}

-- Video configuration lives in 68000 registers, not RAM.
--   0ff001 flip screen        0ff002 scroll Y layer 0
--   0ff004 scroll X layer 1   0ff006 scroll Y layer 1
--   0ff008-0ff00b gfx banks, four nibbles per word, 8 banks total
local flip, scry0, scrx1, scry1, bank0, bank1 = 0, 0, 0, 0, 0, 0
local mem = manager.machine.devices[":maincpu"].spaces["program"]
vregs_tap = mem:install_write_tap(0x0ff000, 0x0ff00f, "vregs",
  function(offset, data, mask)
    if offset == 0x0ff000 and (mask & 0x00ff) ~= 0 then flip  = data & 0xff end
    if offset == 0x0ff002 then scry0 = data & 0x1ff end
    if offset == 0x0ff004 then scrx1 = data & 0x1ff end
    if offset == 0x0ff006 then scry1 = data & 0x1ff end
    if offset == 0x0ff008 then bank0 = data & 0xffff end
    if offset == 0x0ff00a then bank1 = data & 0xffff end
  end)

local idx = 1

local function capture(frame)
  local dir = string.format("%s/m%05d", OUT, frame)
  os.execute("mkdir -p '"..dir.."'")
  local f = io.open(dir.."/dump.bin","wb")
  for _,r in ipairs(regions) do
    local sh = shares[r.tag]
    for a = 0, sh.size-1 do f:write(string.char(sh:read_u8(a))) end
  end
  f:write(string.char(flip,
                      (scry0 >> 8) & 0xff, scry0 & 0xff,
                      (scrx1 >> 8) & 0xff, scrx1 & 0xff,
                      (scry1 >> 8) & 0xff, scry1 & 0xff, 0))
  f:write(string.char((bank0 >> 8) & 0xff, bank0 & 0xff,
                      (bank1 >> 8) & 0xff, bank1 & 0xff))
  f:close()
  manager.machine.video:snapshot()
  print(string.format("scene m%05d  flip=%02x scry0=%03x scrx1=%03x scry1=%03x banks=%04x/%04x",
        frame, flip, scry0, scrx1, scry1, bank0, bank1))
end

emu.register_frame_done(function()
  local target = idx*STEP
  if idx <= SCENES and screen:frame_number() >= target then
    capture(target); idx = idx + 1
    if idx > SCENES then manager.machine:exit() end
  end
end)
