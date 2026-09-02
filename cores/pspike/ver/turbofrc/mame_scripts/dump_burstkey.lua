-- Burst scene capture: same dump as dump_burst.lua, but one scene per FRAME
-- for as long as the key is held. For artifacts that only flash for a frame or
-- two - the white band as the car leaves the tunnel in the turbofrc attract,
-- around frame 2700-3000 - where 300 frame scene spacing samples nothing.
--
--   hold   \  (backslash)   capture every frame while held
--   TF_MAX                  frames per press, default 30
--
-- Polled from register_periodic, which keeps firing while MAME is PAUSED, so
-- you can pause on the exact frame and then capture.
local shares = manager.machine.memory.shares
local screen; for _,s in pairs(manager.machine.screens) do screen=s; break end
local input = manager.machine.input

local OUT = os.getenv("TF_SCENES") or "cores/pspike/ver/turbofrc/scenes"
local MAX = tonumber(os.getenv("TF_MAX") or "30")
local order = {}
local KEY = input:seq_from_tokens(os.getenv("TF_KEY") or "KEYCODE_BACKSLASH")
-- No key needed: TF_FROM/TF_TO capture every frame in a range and exit.
-- Keyboard layouts differ and a one frame flash is hard to hit by hand
local FROM = tonumber(os.getenv("TF_FROM") or "0")
local TO   = tonumber(os.getenv("TF_TO")   or "0")

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
  order[#order+1] = dir
  manager.machine:popmessage(string.format("CAPTURED m%05d", frame))
  print(string.format("CAPTURED m%05d  flip=%02x scry0=%03x scrx1=%03x scry1=%03x banks=%04x/%04x",
        frame, flip, scry0, scrx1, scry1, bank0, bank1))
end

-- Two triggers, whichever fires first:
--   PAUSE (the P key)  captures on the pause transition - pause on the frame
--                      you want and it is dumped, no extra key needed
--   \                  captures on the spot, works paused or running
local held, was_paused, run, lastfr = false, false, 0, -1
emu.register_periodic(function()
  if TO > 0 then                              -- automatic range capture
    local fr = screen:frame_number()
    if fr >= FROM and fr <= TO and fr ~= lastfr then
      capture(fr); lastfr = fr
    elseif fr > TO then
      manager.machine:exit()
    end
    return
  end
  local paused = manager.machine.paused
  if paused and not was_paused then capture(screen:frame_number()) end
  was_paused = paused

  local now = input:seq_pressed(KEY)
  if now then
    if not held then run = 0 end            -- new press restarts the budget
    local fr = screen:frame_number()
    if fr ~= lastfr and run < MAX then      -- one capture per frame, not per poll
      capture(fr); lastfr = fr; run = run + 1
      if run == MAX then print("   ...TF_MAX reached, release and press again") end
    end
  end
  held = now
end)

if TO > 0 then
  print(string.format("dump_burstkey.lua: auto-capturing frames %d..%d into %s", FROM, TO, OUT))
else
  print(string.format("dump_burstkey.lua ready - HOLD the key to capture consecutive "..
                      "frames (max %d per press) into %s. Or set TF_FROM/TF_TO", MAX, OUT))
end

-- keep the handle in a global: a collected notifier never fires
stop_notifier = emu.add_machine_stop_notifier(function()
  local f = io.open(OUT.."/.capture_order.txt","w")
  for _,dir in ipairs(order) do f:write(dir.."\n") end
  f:close()
  local snapdir = manager.machine.options.entries["snapshot_directory"]:value()
  print(string.format("\n%d scenes captured. Collate the screenshots with:\n"..
    "  paste <(ls -1 '%s'/turbofrc/*.png | sort) '%s/.capture_order.txt' | "..
    "while read s d; do cp \"$s\" \"$d/screen.png\"; done", #order, snapdir, OUT))
end)
