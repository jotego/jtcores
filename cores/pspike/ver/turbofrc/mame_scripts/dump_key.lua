-- Interactive scene capture: same dump as dump_burst.lua, but triggered by a
-- keypress instead of a frame counter, so the scene is whatever is on screen
-- when you hit the key. The scene is named after MAME's own frame number.
--
--   press  \  (backslash)   capture a scene
--
-- Polled from register_periodic, which keeps firing while MAME is PAUSED, so
-- you can pause on the exact frame and then capture.
local shares = manager.machine.memory.shares
local screen; for _,s in pairs(manager.machine.screens) do screen=s; break end
local input = manager.machine.input

local OUT = os.getenv("TF_SCENES") or "cores/pspike/ver/turbofrc/scenes"
local KEY = input:seq_from_tokens("KEYCODE_BACKSLASH")

-- Order must match ver/game/rest2bin.sh
--   vram0 8192, vram1 8192, rascr 4096, oram 2048,
--   lut0 16384, lut1 16384, pal 2048, regs 12   = 57356
local regions = {
  { name = "vram0", tag = ":vram.0"        },
  { name = "vram1", tag = ":vram.1"        },
  { name = "rascr", tag = ":rasterram"     },
  { name = "oram",  tag = ":spriteram"     },
  { name = "lut0",  tag = ":sprlookupram1" },
  { name = "lut1",  tag = ":sprlookupram2" },
  { name = "pal",   tag = ":palette"       },
}

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
  manager.machine:popmessage(string.format("CAPTURED m%05d", frame))
  print(string.format("CAPTURED m%05d  flip=%02x scry0=%03x scrx1=%03x scry1=%03x banks=%04x/%04x",
        frame, flip, scry0, scrx1, scry1, bank0, bank1))
end

-- Two triggers, whichever fires first:
--   PAUSE (the P key)  captures on the pause transition - pause on the frame
--                      you want and it is dumped, no extra key needed
--   \                  captures on the spot, works paused or running
local held, was_paused = false, false
emu.register_periodic(function()
  local paused = manager.machine.paused
  if paused and not was_paused then capture(screen:frame_number()) end
  was_paused = paused

  local now = input:seq_pressed(KEY)
  if now and not held then capture(screen:frame_number()) end
  held = now
end)

print("dump_key.lua ready - PAUSE (P) or \\ captures a scene into "..OUT)
