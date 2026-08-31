-- Dump an f1gp scene on demand: play the game and press '/' to capture.
-- Same dump.bin layout and register order as dump_burst.lua, so the scenes
-- it writes are interchangeable with the burst ones.
local shares = manager.machine.memory.shares
local screen; for _,s in pairs(manager.machine.screens) do screen=s; break end

local OUT = os.getenv("F1GP_SCENES") or "cores/f1grpr/ver/f1gp/scenes"
local KEY = os.getenv("F1GP_KEY") or "KEYCODE_SLASH"
-- headless self-test: F1GP_FORCE=<frame> captures once and exits
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
  -- snapshot lands in MAME's snap dir; move the newest one in as screen.png
  manager.machine.video:snapshot()
  os.execute(string.format(
    "sleep 0.2; s=$(ls -t '%s'/f1gp/*.png 2>/dev/null | head -1); "..
    "[ -n \"$s\" ] && mv \"$s\" '%s/screen.png'", snapdir, dir))
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
local held = false
emu.register_frame_done(function()
  local fr = screen:frame_number()
  if FORCE > 0 then
    if fr >= FORCE then capture(fr); manager.machine:exit() end
    return
  end
  local now = manager.machine.input:code_pressed(key)
  if now and not held then capture(fr) end
  held = now
end)
print("dump_key.lua ready: press '/' to capture -> "..OUT)
