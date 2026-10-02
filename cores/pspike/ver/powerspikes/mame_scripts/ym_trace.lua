-- Trace every YM2610 register write for the first N frames of Power Spikes.
--
-- pspikes uses spinlbrk_sound_portmap: ports 18-1b on the Z80 I/O space.
--   18 = bank0 address   19 = bank0 data   1a = bank1 address   1b = bank1 data
-- ADPCM-A lives in bank 1:
--   100      bit7 0=key on / 1=dump, bits[5:0] channel mask
--   101      TL, bits[5:0]
--   108-10d  per channel: bits[7:6] = R/L output enable, bits[4:0] = level
--   110-11f  start address L/H, in 256-byte units
--   120-12f  end address   L/H
--
-- The point of the L/R bits: a channel with both clear streams sample ROM
-- exactly like a playing one but is inaudible, which is what we are chasing.

local FRAMES = tonumber(os.getenv("YM_FRAMES") or "620")
local screen; for _,s in pairs(manager.machine.screens) do screen=s; break end
local io_sp = manager.machine.devices[":audiocpu"].spaces["io"]

local b0_reg, b1_reg = 0, 0
local kon_n, koff_n = 0, 0
-- per ADPCM-A channel state
local ch = {}
for i=0,5 do ch[i] = { lr=nil, lvl=nil, kon=0, startlo=0, starthi=0, endlo=0, endhi=0 } end

local function bank1(reg, data)
    if reg == 0x00 then
        local mask = data & 0x3f
        if (data & 0x80) ~= 0 then
            koff_n = koff_n + 1
        else
            kon_n = kon_n + 1
            for i=0,5 do
                if (mask & (1<<i)) ~= 0 then
                    ch[i].kon = ch[i].kon + 1
                    local st = (ch[i].starthi<<8 | ch[i].startlo) * 256
                    local en = (ch[i].endhi  <<8 | ch[i].endlo  ) * 256
                    print(string.format(
                      "f%-5d KEYON ch%d  start=%06X end=%06X  lr=%s lvl=%s",
                      screen:frame_number(), i, st, en,
                      ch[i].lr and string.format("%d%d",(ch[i].lr>>1)&1, ch[i].lr&1) or "??",
                      ch[i].lvl and string.format("%02d",ch[i].lvl) or "??"))
                end
            end
        end
    elseif reg == 0x01 then
        print(string.format("f%-5d ADPCM-A TL = %02x", screen:frame_number(), data & 0x3f))
    elseif reg >= 0x08 and reg <= 0x0d then
        local c = reg - 0x08
        ch[c].lr  = (data >> 6) & 3
        ch[c].lvl = data & 0x1f
    elseif reg >= 0x10 and reg <= 0x1f then
        local c = reg & 7
        if reg < 0x18 then ch[c].startlo = data else ch[c].starthi = data end
    elseif reg >= 0x20 and reg <= 0x2f then
        local c = reg & 7
        if reg < 0x28 then ch[c].endlo = data else ch[c].endhi = data end
    end
end

-- ADPCM-B (delta-T) lives in bank 0, regs 10-1c:
--   10 bit7 START bit4 REPEAT bit0 RESET   11 bits[7:6] = R/L pan
--   12/13 start L/H   14/15 end L/H   19/1a delta-N   1b level
local bst = { lo=0, hi=0, elo=0, ehi=0, pan=nil, lvl=nil, dn=0, dnh=0, n=0 }
local function bank0(reg, data)
    if reg == 0x10 then
        if (data & 0x80) ~= 0 then
            bst.n = bst.n + 1
            print(string.format(
              "f%-5d B-START      start=%06X end=%06X  pan=%s lvl=%s deltaN=%04X rep=%d",
              screen:frame_number(),
              (bst.hi<<8 | bst.lo)*256, (bst.ehi<<8 | bst.elo)*256,
              bst.pan and string.format("%d%d",(bst.pan>>1)&1, bst.pan&1) or "??",
              bst.lvl and string.format("%03d",bst.lvl) or "??",
              (bst.dnh<<8 | bst.dn), (data>>4)&1))
        end
    elseif reg == 0x11 then bst.pan = (data >> 6) & 3
    elseif reg == 0x12 then bst.lo  = data
    elseif reg == 0x13 then bst.hi  = data
    elseif reg == 0x14 then bst.elo = data
    elseif reg == 0x15 then bst.ehi = data
    elseif reg == 0x19 then bst.dn  = data
    elseif reg == 0x1a then bst.dnh = data
    elseif reg == 0x1b then bst.lvl = data end
end

tap = io_sp:install_write_tap(0x18, 0x1b, "ym", function(offset, data, mask)
    local d = data & 0xff
    if     offset == 0x18 then b0_reg = d
    elseif offset == 0x19 then bank0(b0_reg, d)
    elseif offset == 0x1a then b1_reg = d
    elseif offset == 0x1b then bank1(b1_reg, d) end
end)

emu.register_frame_done(function()
    if screen:frame_number() >= FRAMES then
        print("")
        print(string.format("=== first %d frames: ADPCM-A keyon=%d keyoff=%d | ADPCM-B starts=%d", FRAMES, kon_n, koff_n, bst.n))
        print("ch  keyons  lr  level")
        for i=0,5 do
            print(string.format(" %d  %6d  %s  %s", i, ch[i].kon,
                ch[i].lr  and string.format("%d%d",(ch[i].lr>>1)&1, ch[i].lr&1) or "--",
                ch[i].lvl and string.format("%02d",ch[i].lvl) or "--"))
        end
        manager.machine:exit()
    end
end)

print("ym_trace.lua ready")
