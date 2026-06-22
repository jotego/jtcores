-- dump_sprites.lua — capture ddribble's OBJ (sprite) + tile RAM and a
-- screenshot at a spread of attract-mode frames, so we get ground-truth
-- (sprite-RAM-bytes  ->  rendered-sprite) pairs from the REAL 005885 to
-- validate our HDL sprite engine against.
--
-- WHY: our jtddribble_5885_7121_obj.v is the 007121 sprite engine. The
-- 005885 stores its sprite attributes differently (see
-- doc/005885_sprite_format.md). This dump lets us decode actual ddribble
-- sprites per MAME's draw_sprites() and confirm what each byte means,
-- rather than guessing from the Iron Horse reference alone.
--
-- ddribble main-CPU memory map (konami/ddribble.cpp:387-392):
--   0x2000-0x2FFF  fg_videoram   (chip 1 / E16 tile RAM)
--   0x3000-0x3FFF  spriteram[0]  (chip 1 / E16 OBJ RAM)   <- 5-byte entries
--   0x6000-0x6FFF  bg_videoram   (chip 2 / H16 tile RAM)
--   0x7000-0x7FFF  spriteram[1]  (chip 2 / H16 OBJ RAM)   <- 5-byte entries
-- draw_sprites() lengths: spriteram[0]=0x07d, spriteram[1]=0x140.
--
-- Output (per target frame F, in /tmp):
--   /tmp/ddribble_<F>_spr0.bin   256 B  (chip 1 sprite RAM, 0x3000..0x30FF)
--   /tmp/ddribble_<F>_spr1.bin   512 B  (chip 2 sprite RAM, 0x7000..0x71FF)
--   /tmp/ddribble_<F>_fgram.bin  4 KB   (chip 1 tile RAM)
--   /tmp/ddribble_<F>_bgram.bin  4 KB   (chip 2 tile RAM)
--   /tmp/ddribble_<F>_screen.png (MAME reference screenshot)
--   /tmp/ddribble_<F>_sprites.txt (human-readable decode of both sprite
--                                  lists per MAME's draw_sprites format)
--
-- Run (from repo root):
--   ~/Emus/mame0276-arm64/mame -rompath ~/.mame/roms-local ddribble \
--       -autoboot_script cores/ddribble/ver/ddribble/mame_scripts/dump_sprites.lua \
--       -autoboot_delay 1 -nothrottle -seconds_to_run 65 -video none
--   then: cores/ddribble/ver/ddribble/mame_scripts/dump_sprites.sh   (collates)

local mem    = manager.machine.devices[":maincpu"].spaces["program"]
local screen = nil
for _, scr in pairs(manager.machine.screens) do screen = scr; break end

-- Frame targets across the attract loop. Tweak freely. The interesting
-- ones are gameplay/demo frames where player sprites are on screen.
local targets = {}
for f = 300, 6000, 300 do targets[#targets+1] = f end
local idx = 1

local function dump_region(path, base, len)
    local f = io.open(path, "wb")
    for a = 0, len-1 do f:write(string.char(mem:read_u8(base + a))) end
    f:close()
end

-- Decode one 5-byte sprite per MAME ddribble draw_sprites() and append to txt.
-- byte[0]=code[7:0]  byte[1]:[7:4]=color [2:0]=code[10:8]
-- byte[2]=Y          byte[3]=X[7:0]      byte[4]: bit0=X8 [4:2]=size 0x20=flipx 0x40=flipy
local function decode_list(txt, base, len, tag)
    txt:write(string.format("--- %s (%d bytes, %d sprites) ---\n", tag, len, len//5))
    local i = 0
    while i + 4 < len do
        local b0 = mem:read_u8(base+i)
        local b1 = mem:read_u8(base+i+1)
        local b2 = mem:read_u8(base+i+2)
        local b3 = mem:read_u8(base+i+3)
        local b4 = mem:read_u8(base+i+4)
        local number = b0 | ((b1 & 0x07) << 8)
        local color  = (b1 & 0xf0) >> 4
        local y      = b2
        local x      = b3 | ((b4 & 0x01) << 8)
        local flipx  = (b4 & 0x20) ~= 0
        local flipy  = (b4 & 0x40) ~= 0
        local szbits = b4 & 0x1c
        local size   = (szbits==0x10) and "32x32" or (szbits==0x08) and "16x32"
                       or (szbits==0x04) and "32x16" or "16x16"
        txt:write(string.format(
          "  [%02X] raw=%02X %02X %02X %02X %02X  num=%03X col=%X x=%3d y=%3d fx=%s fy=%s sz=%s\n",
          i//5, b0,b1,b2,b3,b4, number,color,x,y, tostring(flipx),tostring(flipy), size))
        i = i + 5
    end
end

local function capture(frame)
    local p = string.format("/tmp/ddribble_%05d", frame)
    dump_region(p.."_pal.bin",   0x1800, 0x080)   -- palette RAM (128 B, xBGR_555)
    dump_region(p.."_spr0.bin",  0x3000, 0x100)
    dump_region(p.."_spr1.bin",  0x7000, 0x200)
    dump_region(p.."_fgram.bin", 0x2000, 0x1000)
    dump_region(p.."_bgram.bin", 0x6000, 0x1000)
    local txt = io.open(p.."_sprites.txt", "w")
    decode_list(txt, 0x3000, 0x07d, "spriteram[0] / chip 1 (E16) gfx1@0x20000")
    decode_list(txt, 0x7000, 0x140, "spriteram[1] / chip 2 (H16) gfx2@0x40000")
    txt:close()
    -- Screenshot is best-effort: the snapshot API differs across MAME
    -- builds. Try screen:snapshot(path), then a no-arg fallback; never let
    -- a snapshot failure abort the RAM dump (the .bin/.txt are the payload).
    if screen ~= nil then
        local ok = pcall(function() screen:snapshot(p.."_screen.png") end)
        if not ok then pcall(function() manager.machine.video:snapshot() end) end
    end
    print(string.format("[ddribble] frame=%05d  sprite/tile RAM + decode + snapshot", frame))
end

local function on_frame_done()
    if idx > #targets then return end
    local cur = screen ~= nil and screen:frame_number() or 0
    while idx <= #targets and cur >= targets[idx] do
        capture(targets[idx]); idx = idx + 1
    end
    if idx > #targets then
        print("[ddribble] all targets captured")
        local ok = pcall(function() manager.machine:exit() end)
        if not ok then pcall(function() emu.exit() end) end
    end
end

emu.register_frame_done(on_frame_done, "ddribble_dump")
print(string.format(">> ddribble sprite dump armed: %d targets <<", #targets))
