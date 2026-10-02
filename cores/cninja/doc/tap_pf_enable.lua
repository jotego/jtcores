-- Report deco16ic playfield ENABLE transitions with frame numbers.
--
-- Per deco16_pf_update (the code, not the register comment above it):
--   pf1 control0 = control[5] & 0xff   -> enable = control[5] bit 7
--   pf2 control0 = control[5] >> 8     -> enable = control[5] bit 15
-- cninja: tilegen0 pf1=fg pf2=mg ; tilegen1 pf1=pf1b pf2=bg(waterfall backdrop)
--
--   ln -sf ../cores/cninja/doc/cninja_lvl2.inp inp/cninja_lvl2.inp
--   mame cninja -playback cninja_lvl2.inp -exit_after_playback \
--        -autoboot_script cores/cninja/doc/tap_pf_enable.lua -autoboot_delay 0 \
--        -nothrottle -video none
_G.taps, _G.frames, _G.last = {}, 0, {}

local function watch(addr, tag, pf1name, pf2name)
    local sp = manager.machine.devices[":maincpu"].spaces["program"]
    _G.taps[#_G.taps+1] = sp:install_write_tap(addr, addr+1, tag,
        function(offset, data, mask)
            local pf1 = (data & 0x0080) ~= 0 and 1 or 0
            local pf2 = (data & 0x8000) ~= 0 and 1 or 0
            local key = string.format("%d%d", pf1, pf2)
            if _G.last[tag] ~= key then
                print(string.format("f%-6d %s ctrl5=%04X  %s=%d  %s=%d",
                    _G.frames, tag, data, pf1name, pf1, pf2name, pf2))
                _G.last[tag] = key
            end
        end)
end

watch(0x14000a, "tg0", "fg  ", "mg")
watch(0x15000a, "tg1", "pf1b", "bg")

emu.register_frame_done(function() _G.frames = _G.frames + 1 end)
