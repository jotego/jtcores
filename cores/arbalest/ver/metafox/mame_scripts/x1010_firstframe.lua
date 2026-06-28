-- Report the frame number of the first X1-010 write / keyon. Writes the file
-- immediately on detection (seconds_to_run can skip stop notifiers).
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local frame = 0
local done_write, done_keyon = false, false
local f = io.open("x1010_frames.txt","w")
emu.register_frame_done(function() frame = frame + 1 end)
mem:install_write_tap(0x100000, 0x103fff, "x1", function(offs, data, mask)
    if not done_write then
        f:write(string.format("first_write_frame=%d\n", frame)); f:flush()
        done_write = true
    end
    local word = (offs - 0x100000) >> 1
    if (word & 7) == 0 and (data & 0x0101) ~= 0 and not done_keyon then
        f:write(string.format("first_keyon_frame=%d\n", frame)); f:flush()
        done_keyon = true
    end
end)
