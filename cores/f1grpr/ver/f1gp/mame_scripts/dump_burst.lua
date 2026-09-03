-- Capture a burst of f1gp scenes: the RAM the video hardware reads, plus a
-- screen.png reference, in a single MAME run.
--   20 scenes, 300 frames apart, from frame 300 (5s) to 6000 (100s @60Hz)
local shares = manager.machine.memory.shares
local screen; for _,s in pairs(manager.machine.screens) do screen=s; break end

local OUT   = os.getenv("F1GP_SCENES") or "cores/f1grpr/ver/f1gp/scenes"
local FIRST = tonumber(os.getenv("F1GP_FIRST") or "300")
local STEP  = tonumber(os.getenv("F1GP_STEP")  or "300")
local COUNT = tonumber(os.getenv("F1GP_COUNT") or "20")
-- appended to the scene name, "o"/"f" for a straight/flipped register pair
local SUF   = os.getenv("F1GP_SUFFIX") or ""
-- explicit frame list, overrides FIRST/STEP/COUNT
local LIST  = {}
for f in (os.getenv("F1GP_FRAMES") or ""):gmatch("%d+") do LIST[#LIST+1] = tonumber(f) end
if #LIST > 0 then COUNT = #LIST end

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

-- gfxctrl and the fg scroll live in 68000 registers, not RAM, so they are
-- caught on the way past and appended to the dump
local gfxctrl, scrx, scry = 0, 0, 0
-- Konami 053936 control, fff040-fff05f: 16 registers. jt053936 restores
-- itself from psac.bin, byte 2i = low, 2i+1 = high (see jt053936.v)
local roz = {}
for i = 0, 15 do roz[i] = 0 end
-- C7-01 GGA, fff020-fff023: an address latch and a data port. Scene replay
-- has no CPU to program the grid, so the register file is captured too and
-- jtpspike_gga restores it from gga.bin
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
    if offset == 0xfff022 then galatch = b & 0x0f   -- fff023: address
    else                       gga[galatch] = b end -- fff021: data
  end)

rozregs_tap = mem:install_write_tap(0xfff040, 0xfff05f, "rozregs",
  function(offset, data, mask)
    local idx = (offset - 0xfff040) >> 1
    if idx >= 0 and idx <= 15 then roz[idx] = data & 0xffff end
  end)

local function capture(frame)
  local dir = string.format("%s/m%05d%s", OUT, frame, SUF)
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
  manager.machine.video:snapshot()
  print(string.format("CAPTURED m%05d  gfxctrl=%02x scrx=%03x scry=%03x",
        frame, gfxctrl, scrx, scry))
  print(string.format("   roz %04x %04x %04x %04x  %04x %04x %04x %04x",
        roz[0],roz[1],roz[2],roz[3],roz[6],roz[7],roz[8],roz[9]))
  print(string.format("   gga %02x %02x %02x %02x  %02x %02x %02x %02x",
        gga[0],gga[1],gga[2],gga[3],gga[8],gga[9],gga[10],gga[11]))
end

local n = 0
emu.register_frame_done(function()
  local fr = screen:frame_number()
  local want = LIST[n+1] or (FIRST + n*STEP)
  if n < COUNT and fr >= want then
    capture(want)
    n = n + 1
    if n >= COUNT then manager.machine:exit() end
  end
end)
print("dump_burst.lua ready -> "..OUT)
