-- Capture 20 Karate Blazers scenes, 300 frames apart, in ONE MAME run.
--
-- Read from the memory SHARES, not the CPU space: the sprite RAM region is
-- write only and reads back as zero through mem:read_u8.
--
-- read_u8 walks ascending addresses, so the file is big endian (68000 order);
-- mem.yaml declares the BRAM simfiles big_endian to match.
--
-- karatblz differs from turbofrc: NO raster RAM (layer 0 scroll X is a plain
-- register at 0ff008) and the sprite lookup RAMs are 64 KB each, not 16 KB.
local shares = manager.machine.memory.shares
local screen; for _,s in pairs(manager.machine.screens) do screen=s; break end

local SCENES, STEP = 20, 300
local OUT = os.getenv("KB_SCENES") or "cores/pspike/ver/karatblz/scenes"

-- Order must match ver/game/rest2bin.sh
--   vram0 8192, vram1 8192, oram 2048,
--   lut0 65536, lut1 65536, pal 2048, regs 10  = 151562
local regions = {
  { name = "vram0", tag = ":vram.0"        },
  { name = "vram1", tag = ":vram.1"        },
  { name = "oram",  tag = ":spriteram"     },
  { name = "lut0",  tag = ":sprlookupram1" },
  { name = "lut1",  tag = ":sprlookupram2" },
  { name = "pal",   tag = ":palette"       },
}

-- Video configuration lives in 68000 registers, not RAM.
--   0ff000 flip screen (bit 7)   0ff002 gfx bank (bit 0 -> 0, bit 3 -> 1)
--   0ff008 scroll X layer 0      0ff00a scroll Y layer 0
--   0ff00c scroll X layer 1      0ff00e scroll Y layer 1
local flip, scrx0, scry0, scrx1, scry1, bank = 0, 0, 0, 0, 0, 0
local mem = manager.machine.devices[":maincpu"].spaces["program"]
vregs_tap = mem:install_write_tap(0x0ff000, 0x0ff00f, "vregs",
  function(offset, data, mask)
    if offset == 0x0ff000 and (mask & 0xff00) ~= 0 then flip = (data >> 8) & 0xff end
    if offset == 0x0ff002 then bank  = data & 0xff end
    if offset == 0x0ff008 then scrx0 = data & 0x1ff end
    if offset == 0x0ff00a then scry0 = data & 0x1ff end
    if offset == 0x0ff00c then scrx1 = data & 0x1ff end
    if offset == 0x0ff00e then scry1 = data & 0x1ff end
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
                      (scrx0 >> 8) & 0xff, scrx0 & 0xff,
                      (scry0 >> 8) & 0xff, scry0 & 0xff,
                      (scrx1 >> 8) & 0xff, scrx1 & 0xff,
                      (scry1 >> 8) & 0xff, scry1 & 0xff,
                      bank))
  f:close()
  manager.machine.video:snapshot()
  print(string.format("scene m%05d  flip=%02x scr0=%03x/%03x scr1=%03x/%03x bank=%02x",
        frame, flip, scrx0, scry0, scrx1, scry1, bank))
end

emu.register_frame_done(function()
  local target = idx*STEP
  if idx <= SCENES and screen:frame_number() >= target then
    capture(target); idx = idx + 1
    if idx > SCENES then manager.machine:exit() end
  end
end)
