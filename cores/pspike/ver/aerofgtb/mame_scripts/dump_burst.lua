-- Capture 20 Aero Fighters scenes, 300 frames apart, in ONE MAME run.
--
-- Aero Fighters shows nothing before about frame 1800, so the earliest scenes
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
-- AF_FRAMES="300,1200,2406" captures exactly those frames instead of the
-- regular burst, for scenes that were originally grabbed by hand
local LIST = {}
for f in (os.getenv("AF_FRAMES") or ""):gmatch("%d+") do LIST[#LIST+1] = tonumber(f) end
table.sort(LIST)
local OUT = os.getenv("AF_SCENES") or "cores/pspike/ver/aerofgtb/scenes"

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
vregs_tap = mem:install_write_tap(0x0fe000, 0x0fe00f, "vregs",
  function(offset, data, mask)
    if offset == 0x0fe000 and (mask & 0x00ff) ~= 0 then flip  = data & 0xff end
    if offset == 0x0fe002 then scry0 = data & 0x1ff end
    if offset == 0x0fe004 then scrx1 = data & 0x1ff end
    if offset == 0x0fe006 then scry1 = data & 0x1ff end
    if offset == 0x0fe008 then bank0 = data & 0xffff end
    if offset == 0x0fe00a then bank1 = data & 0xffff end
  end)

-- The GGA holds the raster geometry, which aerofgtb reprograms to 320x224.
-- Scene replay is NOMAIN so the register file would otherwise sit at its
-- 352x240 reset defaults - jtpspike_gga restores it from gga.bin
local gga, gga_a = {}, 0
for i = 0, 15 do gga[i] = 0 end
gga_tap = mem:install_write_tap(0x0fe400, 0x0fe403, "gga",
  function(offset, data, mask)
    if (mask & 0x00ff) == 0 then return end
    if (offset & 2) ~= 0 then gga_a = data & 0x0f
    else                      gga[gga_a] = data & 0xff end
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
  for i = 0, 15 do f:write(string.char(gga[i])) end
  f:close()
  manager.machine.video:snapshot()
  print(string.format("scene m%05d  flip=%02x scry0=%03x scrx1=%03x scry1=%03x banks=%04x/%04x",
        frame, flip, scry0, scrx1, scry1, bank0, bank1))
  local g = {}
  for i = 0, 15 do g[#g+1] = string.format("%02x", gga[i]) end
  print("   gga "..table.concat(g, " "))
end

burst_cb = emu.register_frame_done(function()
  local target = (#LIST > 0) and LIST[idx] or (idx*STEP)
  local last   = (#LIST > 0) and #LIST or SCENES
  if idx <= last and screen:frame_number() >= target then
    capture(target); idx = idx + 1
    if idx > last then manager.machine:exit() end
  end
end)
