-- Observe public sound-CPU bus writes without changing their values.
-- Launch through JTFRAME's mamedbg.lua wrapper with TRACE_DIR set.
local root = assert(os.getenv("TRACE_DIR"), "TRACE_DIR is required")
local machine = manager.machine
local cpu = assert(machine.devices[":audiocpu"])
local output = assert(io.open(root .. "/bus.csv", "w"))
local derived = assert(io.open(root .. "/registers.csv", "w"))
local info = assert(io.open(root .. "/capture.txt", "w"))
local start = machine.time
local address, previous = nil, nil
local transactions, writes, frames = 0, 0, 0
local closed = false
output:write("seconds,attoseconds,address,value,mask\n")
info:write(string.format("start_seconds=%d\nstart_attoseconds=%d\nsource_clock_hz=4000000\n",
    start.seconds, start.attoseconds))
local function close(reason)
    if closed then return end
    closed = true
    info:write(string.format("reason=%s\ntransactions=%d\nwrites=%d\nframes=%d\nend_seconds=%d\nend_attoseconds=%d\n",
        reason, transactions, writes, frames, machine.time.seconds, machine.time.attoseconds))
    output:close(); derived:close(); info:close()
end
MAMEDBG.add_cleanup(function() close("wrapper_cleanup") end)
-- Retain the handler for the lifetime of the capture.
_G.rastan_trace_tap = cpu.spaces["program"]:install_write_tap(0x9000, 0x9001,
    "ym2151_register_capture", function(offset, data, mask)
        local now = machine.time
        transactions = transactions + 1
        output:write(string.format("%d,%d,%d,%d,%d\n", now.seconds, now.attoseconds,
            offset, data, mask))
        if offset == 0x9000 then
            address = data
        else
            assert(address, "data write without a captured address")
            local delta = previous and (now - previous):as_double() or 0
            derived:write(string.format("%.18f,%d,%d\n", delta, address, data))
            previous = emu.attotime(now)
            writes = writes + 1
        end
    end)
emu.register_frame_done(function()
    frames = frames + 1
    if os.getenv("TRACE_PLAY") == "1" or os.getenv("TRACE_PLAY") == "2" then
        local system = machine.ioport.ports[":SYSTEM"]
        if frames == 180 then system:field(0x20):set_value(1); info:write("coin1_on_frame=180\n") end
        if frames == 186 then system:field(0x20):clear_value(); info:write("coin1_off_frame=186\n") end
        if frames == 240 then system:field(0x08):set_value(1); info:write("start1_on_frame=240\n") end
        if frames == 246 then system:field(0x08):clear_value(); info:write("start1_off_frame=246\n") end
        if os.getenv("TRACE_PLAY") == "2" and frames >= 420 then
            local p1 = machine.ioport.ports[":P1"]
            if frames == 420 then p1:field(0x08):set_value(1); info:write("right_on_frame=420\n") end
            if frames % 20 == 0 then p1:field(0x10):set_value(1) end
            if frames % 20 == 6 then p1:field(0x10):clear_value() end
            if frames == 420 then info:write("button1_period_frames=20\nbutton1_on_frames=6\n") end
        end
    end
    if machine.time:as_double() >= tonumber(os.getenv("TRACE_SECONDS") or "30") then
        close("emulated_time_limit")
        MAMEDBG.exit("Rastan trace complete")
    end
end, "rastan_trace_end")
manager.machine.debugger:command("g")
