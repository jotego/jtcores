-- per-frame MISC/IN1/IN2/ACCEL/WHEEL during -playback, input for ../inp2cab.py
-- run from ~/develop/mame: ./mame speedrcr -rompath roms -input_directory <dir> -playback speed1.inp
--   -exit_after_playback -video none -sound none -nothrottle -autoboot_script log_ports.lua
nframes = 0
out = io.open("speed1_ports.txt","w")
ports = manager.machine.ioport.ports
log_sub = emu.add_machine_frame_notifier(function()
    out:write(string.format("%d %02x %02x %02x %02x %02x\n", nframes,
        ports[":MISC"]:read(), ports[":IN1"]:read(), ports[":IN2"]:read(),
        ports[":ACCEL"]:read(), ports[":WHEEL"]:read()))
    out:flush()
    nframes = nframes + 1
end)
