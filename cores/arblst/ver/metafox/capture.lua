-- Used with the maintained MAME scene binary and -autoboot_delay 0.
-- METAFOX_FLIP: 2 = DIP off (normal); 0 = DIP on (flipped).
local frame = 0
local ports = manager.machine.ioport.ports
local flip = tonumber(os.getenv('METAFOX_FLIP') or '2')
assert(flip == 0 or flip == 2, 'METAFOX_FLIP must be 0 or 2')
emu.register_frame_done(function()
    frame = frame + 1
    for _, port in pairs(ports) do
        for name, field in pairs(port.fields) do
            if name == 'Coin 1' then
                field:set_value((frame >= 600 and frame < 604) and 1 or 0)
            elseif name == '1 Player Start' then
                field:set_value((frame >= 800 and frame < 830) and 1 or 0)
            elseif name == 'Flip Screen' then
                field.user_value = flip
            end
        end
    end
end, 'metafox-inputs')
