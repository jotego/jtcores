-- Exercise the actual assembled HuC6280 binary using MAME's CPU/YM2151.
local root = assert(os.getenv("JTROOT")) .. "/tasks/jtcores-143/"
local file = assert(io.open(root .. "artifacts/monitor.bin", "rb"))
local image = file:read("a")
file:close()
local cpu = manager.machine.devices[":audiocpu"]
local space = cpu.spaces["program"]
local rom = manager.machine.memory.regions[":audiocpu"]
local replies, writes = {}, {}
local seq = 0
local taps = {}
-- Tap handles remove themselves when garbage collected.
_G.monitor_taps = taps
taps[1] = space:install_read_tap(0x3f00, 0x3fff, "picorom_tx", function(offset, data, mask)
    replies[#replies+1] = offset & 255
    seq = (seq + 1) & 255
    rom:write_u8(0x3c10, seq)
    return data
end)
taps[2] = space:install_write_tap(0x110000, 0x110001, "ym_writes", function(offset, data, mask)
    writes[#writes+1] = {offset, data}
end)
local function submit(gen, bytes)
    for i,v in ipairs(bytes) do rom:write_u8(0x4000+i-1, v) end
    rom:write_u8(0x2000, gen)
    rom:write_u8(0x2001, gen ~ 255)
end
local frame, stage = 0, 0
local tone_frame
local function check(condition, message)
    if not condition then error(message) end
end
emu.register_frame_done(function()
    frame = frame + 1
    if frame == 1 then
        for i=1,#image do rom:write_u8(i-1, image:byte(i)) end
        -- Re-enter only the sound CPU; a machine reset reruns autoboot Lua.
        for i=0,7 do cpu.state["MPR" .. i].value = 0 end
        cpu.state["P"].value = 0x14
        cpu.state["PC"].value = 0xe000
        stage = 1
    elseif stage == 1 and #replies >= 3 then
        check(replies[1] == 0xb0 and replies[2] == 0, "bad boot reply")
        submit(1, {1,0x10,255, 1,0x11,3, 1,0x14,5, 2,255,255, 3,0})
        stage = 2
    elseif stage == 2 and #replies >= 6 then
        check(replies[4] == 0xd0 and replies[5] == 1 and (replies[6] & 3) == 1,
              "timer A did not overflow")
        submit(2, {1,0x14,0x30, 2,255,0, 3,0})
        stage = 3
    elseif stage == 3 and #replies >= 9 then
        check(replies[7] == 0xd0 and replies[8] == 2 and (replies[9] & 3) == 0,
              "timer status did not clear on live reload")
        check(#writes == 8, "unexpected YM2151 write count: " .. #writes)
        local labels = assert(io.open(root .. "artifacts/monitor.lbl", "r")):read("a")
        local idle = tonumber(assert(labels:match("al (%x+) %.idle")),16)
        check(cpu.state["PC"].value >= 0x2200 and cpu.state["PC"].value < 0x2300,
              "CPU left resident RAM")
        print("PASS: RAM test, boot reply, timer overflow, status reset, two live command generations")
        for i,v in ipairs(replies) do io.write(string.format("%02x ",v)) end
        io.write("\n")
        if os.getenv("CHECK_TONE") then
            local tone = assert(io.open(root .. "artifacts/tone-table.bin", "rb")):read("a")
            local bytes = {tone:byte(1,#tone)}
            submit(3,bytes)
            tone_frame = frame
            stage = 4
        else
            manager.machine:exit()
            stage = 6
        end
    elseif stage == 4 and #replies >= 12 then
        check(replies[10] == 0xd0 and replies[11] == 3 and replies[12] == 0,
              "tone command failed")
        stage = 5
    elseif stage == 5 and frame-tone_frame >= 120 then
        print("PASS: tone bytecode crossed multiple ROM pages and completed")
        manager.machine:exit()
        stage = 6
    elseif frame == 180 then
        print(string.format("FAIL: monitor timeout: stage=%d PC=%04x replies=%d writes=%d",
                            stage,cpu.state["PC"].value,#replies,#writes))
        stage = 4
        manager.machine:exit()
    end
end, "monitor-test")
