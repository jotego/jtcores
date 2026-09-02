-- Dump f1gp scenes on CONSECUTIVE frames for as long as '/' is held down.
--
-- For catching something that only shows while it moves - e.g. a sprite leaving
-- the screen depositing a column at the far edge. One shot per keypress is too
-- coarse: hold the key through the event and every frame lands as its own scene,
-- so the sequence can be replayed and diffed frame by frame.
--
-- Same dump.bin layout and register order as dump_burst.lua, so the scenes it
-- writes are interchangeable with the burst and single-shot ones.
--
--   F1GP_MAX    stop after this many frames in one press (default 30)
--   F1GP_KEY    capture key (default KEYCODE_SLASH)
--   F1GP_SCENES output folder
local shares = manager.machine.memory.shares
local screen; for _,s in pairs(manager.machine.screens) do screen=s; break end

local OUT = os.getenv("F1GP_SCENES") or "cores/f1grpr/ver/f1gp/scenes"
local KEY = os.getenv("F1GP_KEY") or "KEYCODE_SLASH"
local MAX = tonumber(os.getenv("F1GP_MAX") or "30")
-- headless self-test: F1GP_FORCE=<frame> captures MAX frames from there and exits
local FORCE = tonumber(os.getenv("F1GP_FORCE") or "0")

-- Order must match the sim-side splitter when scene replay is built
local regions = {
  { name = "fgvram",  tag = ":fgvideoram"  },  --   4 kB
  { name = "rozvram", tag = ":rozvideoram" },  --   8 kB
  { name = "rozgfx",  tag = ":rozgfxram"   },  -- 256 kB
  { name = "oram0",   tag = ":spr1vram"    },  --   1 kB
  { name = "oram1",   tag = ":spr2vram"    },  --   1 kB
  { name = "lut0",    tag = ":spr1cgram"   },  --  16 kB
  { name = "lut1",    tag = ":spr2cgram"   },  --  16 kB
  { name = "pal",     tag = ":palette"     },  --   4 kB
}

local order = {}
local gfxctrl, scrx, scry = 0, 0, 0
local roz = {}; for i = 0, 15 do roz[i] = 0 end
local gga, galatch = {}, 0
for i = 0, 15 do gga[i] = 0 end

local mem = manager.machine.devices[":maincpu"].spaces["program"]
vregs_tap = mem:install_write_tap(0xfff000, 0xfff007, "vregs",
  function(offset, data, mask)
    if offset == 0xfff000 and (mask & 0x00ff) ~= 0 then gfxctrl = data & 0xff end
    if offset == 0xfff002 then scrx = data & 0x1ff end
    if offset == 0xfff004 then scry = data & 0x1ff end
  end)

gga_tap = mem:install_write_tap(0xfff020, 0xfff023, "gga",
  function(offset, data, mask)
    if (mask & 0x00ff) == 0 then return end
    local b = data & 0xff
    if offset == 0xfff022 then galatch = b & 0x0f
    else                       gga[galatch] = b end
  end)

rozregs_tap = mem:install_write_tap(0xfff040, 0xfff05f, "rozregs",
  function(offset, data, mask)
    local idx = (offset - 0xfff040) >> 1
    if idx >= 0 and idx <= 15 then roz[idx] = data & 0xffff end
  end)

local snapdir = manager.machine.options.entries["snapshot_directory"]:value()

local function capture(frame)
  local dir = string.format("%s/m%05d", OUT, frame)
  os.execute("mkdir -p '"..dir.."'")
  local f = io.open(dir.."/dump.bin","wb")
  for _,r in ipairs(regions) do
    local sh = shares[r.tag]
    if sh == nil then print("MISSING SHARE "..r.tag) else
      for a = 0, sh.size-1 do f:write(string.char(sh:read_u8(a))) end
    end
  end
  f:write(string.char(gfxctrl,
                      (scrx >> 8) & 0xff, scrx & 0xff,
                      (scry >> 8) & 0xff, scry & 0xff, 0, 0, 0))
  for i = 0, 15 do
    f:write(string.char(roz[i] & 0xff, (roz[i] >> 8) & 0xff))
  end
  for i = 0, 15 do f:write(string.char(gga[i] & 0xff)) end
  f:close()
  -- Do NOT move the snapshot here: at one capture per frame the shell call and
  -- its sleep stall the emulator and race. Let MAME number its own files and
  -- collate afterwards, in capture order - see the note printed at exit
  manager.machine.video:snapshot()
  order[#order+1] = dir
  print(string.format("CAPTURED m%05d  gfxctrl=%02x scrx=%03x scry=%03x",
        frame, gfxctrl, scrx, scry))
  local r = {}
  for i = 0, 15 do r[#r+1] = string.format("%04x", roz[i]) end
  print("   roz00-07 "..table.concat(r, " ", 1, 8))
  print("   roz08-15 "..table.concat(r, " ", 9, 16))
  local g = {}
  for i = 0, 15 do g[#g+1] = string.format("%02x", gga[i]) end
  print("   gga      "..table.concat(g, " "))
end

local key = manager.machine.input:code_from_token(KEY)
local held, run = false, 0
emu.register_frame_done(function()
  local fr = screen:frame_number()
  if FORCE > 0 then
    if fr >= FORCE then
      capture(fr); run = run + 1
      if run >= MAX then manager.machine:exit() end
    end
    return
  end
  local now = manager.machine.input:code_pressed(key)
  if now then
    if not held then run = 0 end          -- new press, restart the budget
    if run < MAX then
      capture(fr); run = run + 1
      if run == MAX then
        print(string.format("   ...F1GP_MAX=%d reached, release and press again", MAX))
      end
    end
  end
  held = now
end)
print(string.format("dump_burstkey.lua ready: HOLD '/' to capture consecutive frames "..
                    "(max %d per press) -> %s", MAX, OUT))

-- keep the handle in a global: a collected notifier never fires
stop_notifier = emu.add_machine_stop_notifier(function()
  local f = io.open(OUT.."/.capture_order.txt","w")
  for _,dir in ipairs(order) do f:write(dir.."\n") end
  f:close()
  print(string.format("\n%d scenes captured. Collate the screenshots with:\n"..
    "  paste <(ls -1 '%s'/f1gp/*.png | sort) '%s/.capture_order.txt' | "..
    "while read s d; do cp \"$s\" \"$d/screen.png\"; done",
    #order, snapdir, OUT))
end)
