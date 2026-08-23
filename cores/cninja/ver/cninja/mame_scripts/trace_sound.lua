-- MAME sound oracle for cninja: find when the YM2151 first plays notes and how
-- many soundlatch commands the main CPU sends, to compare against jtsim.
-- Run: mame -rompath /tmp/mrom cninja -video none -sound none -seconds_to_run N \
--        -autoboot_script mame_scripts/trace_sound.lua -nothrottle
local out = io.open("/tmp/cninja_snd.log","w")
local cpu = manager.machine.devices[":audiocpu"]
local aspace = cpu.spaces["program"]
local frame, latches, first_note = 0, 0, -1
local ymw = {ym2203=0, ym2151=0, oki1=0, oki2=0}
local ymreg = {}

_G.taps = {}   -- keep handles alive (else GC stops the notifiers/taps)
_G.taps[#_G.taps+1] = aspace:install_read_tap(0x140000, 0x140001, "latchrd", function(off,data,mask)
    latches = latches + 1
    if latches <= 60 then out:write(string.format("LATCH rd f=%d val=%02X\n", frame, data&0xff)) end
    return data
end)
local function tapw(lo,hi,name) _G.taps[#_G.taps+1]=aspace:install_write_tap(lo,hi,name,function(o,d,m) ymw[name]=ymw[name]+1; return d end) end
tapw(0x100000,0x100001,"ym2203")
tapw(0x110000,0x110001,"ym2151")
tapw(0x120000,0x120001,"oki1")
tapw(0x130000,0x130001,"oki2")
_G.taps[#_G.taps+1] = aspace:install_write_tap(0x110000,0x110000,"ymregsel", function(off,data,mask)
    local r=data&0xff; ymreg[r]=(ymreg[r] or 0)+1
    if first_note<0 and (r==0x08 or r>=0x20) then
        first_note=frame; out:write(string.format(">>> first YM2151 voice reg %02X at frame %d\n",r,frame))
    end
    return data
end)
_G.fnotify = emu.add_machine_frame_notifier(function()
    frame = frame + 1
    if frame % 60 == 0 then
        local notes=0; for k,v in pairs(ymreg) do if k==0x08 or k>=0x20 then notes=notes+v end end
        out:write(string.format("[f%d] ym2151w=%d voice_writes=%d first_note=%d latches=%d ym2203w=%d oki1w=%d\n",
            frame, ymw.ym2151, notes, first_note, latches, ymw.ym2203, ymw.oki1))
        out:flush()
    end
end)
