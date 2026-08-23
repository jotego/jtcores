-- Log writes to the two deco16ic control blocks with their byte mask.
-- mask ~= 0xffff is a byte-sized write, which jtcninja_deco16ic must honour per
-- lane (deco16ic::pf_control_w uses COMBINE_DATA).
-- MAME resolves -playback inside its inp/ directory, so link the recording there
-- first (it lives in doc/ so it does not get lost):
--   ln -sf ../cores/cninja/doc/cninja_lvl2.inp inp/cninja_lvl2.inp
--   mame cninja -playback cninja_lvl2.inp -exit_after_playback \
--        -autoboot_script cores/cninja/doc/tap_pf_control.lua -autoboot_delay 0 \
--        -nothrottle -video none
-- Handles live in globals: a collected tap segfaults MAME mid-run.
_G.taps, _G.hist, _G.frames = {}, {}, 0

local function watch(base, tag)
    local sp = manager.machine.devices[":maincpu"].spaces["program"]
    _G.taps[#_G.taps+1] = sp:install_write_tap(base, base+0x0f, tag,
        function(offset, data, mask)
            local k = string.format("%s %06X mask=%04X", tag, offset, mask)
            _G.hist[k] = (_G.hist[k] or 0) + 1
            if mask ~= 0xffff then
                print(string.format("BYTEWRITE %s %06X data=%04X mask=%04X", tag, offset, data, mask))
            end
        end)
end
watch(0x140000, "tg0")
watch(0x150000, "tg1")

emu.register_frame_done(function()
    _G.frames = _G.frames + 1
    if _G.frames % 1800 ~= 0 then return end
    local keys = {}
    for k in pairs(_G.hist) do keys[#keys+1] = k end
    table.sort(keys)
    print(string.format("---- frame %d ----", _G.frames))
    for _,k in ipairs(keys) do print(string.format("%8d  %s", _G.hist[k], k)) end
end)
