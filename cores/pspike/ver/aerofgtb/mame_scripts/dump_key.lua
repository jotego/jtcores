-- Interactive scene capture for Aero Fighters: same dump as dump_burst.lua but
-- triggered by a keypress, so the scene is whatever is on screen when you hit
-- the key. Named after MAME's own frame number.
--
--   press  \  (backslash)   capture a scene
--
-- Polled from register_periodic so it also works while MAME is paused.
local shares = manager.machine.memory.shares
local screen; for _,s in pairs(manager.machine.screens) do screen=s; break end

local SCENES, STEP = 20, 300
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

-- The scene dump does NOT carry the GGA timing table, so a replay always uses
-- the reset defaults. Print every GGA write: if service mode retimes the video,
-- the replay geometry will not match and we need to know that.
local gga_a = 0
gga_tap = mem:install_write_tap(0x0fe400, 0x0fe403, "gga",
  function(offset, data, mask)
    if (offset & 2) ~= 0 then gga_a = data & 0x0f
    else print(string.format("GGA reg %02x = %02x", gga_a, data & 0xff)) end
  end)

local KEY  = manager.machine.input:seq_from_tokens("KEYCODE_BACKSLASH")
local held, was_paused = false, false
emu.register_periodic(function()
  local paused = manager.machine.paused
  if paused and not was_paused then capture(screen:frame_number()) end
  was_paused = paused
  local now = manager.machine.input:seq_pressed(KEY)
  if now and not held then capture(screen:frame_number()) end
  held = now
end)

print("dump_key.lua ready - PAUSE or \\ captures a scene into "..OUT)
