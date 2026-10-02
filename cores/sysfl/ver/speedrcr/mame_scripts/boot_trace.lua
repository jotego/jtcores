-- Boot ground-truth for the jt960 integration: logs what the i960 needs
-- from the C75 (shareram traffic), sysreg writes, first video reg writes
-- and a per-frame PC sample. Output: /tmp/speedrcr_boot.log
--
-- run: ./sysfl speedrcr -rompath roms -video none -sound none -nothrottle \
--        -str 25 -autoboot_script boot_trace.lua

local mem  = manager.machine.devices[":maincpu"].spaces["program"]
local mcu  = manager.machine.devices[":mcu"].spaces["program"]
local cpu  = manager.machine.devices[":maincpu"]
local log  = io.open("/tmp/speedrcr_boot.log","w")

local function pc() return cpu.state["ip"].value end

-- first access per offset + poll counters
seen_rd, seen_wr, seen_mw = {}, {}, {}
rd_polls = {}

-- keep tap handles global or GC kills them
share_rd_tap = mem:install_read_tap(0x30284000, 0x3028bfff, "share_rd",
    function(offset, data, mask)
        local o = offset - 0x30284000
        rd_polls[o] = (rd_polls[o] or 0) + 1
        if not seen_rd[o] then
            seen_rd[o] = true
            log:write(string.format("SHARE_RD off=%04x data=%08x mask=%08x pc=%08x frame=%d\n",
                o, data, mask, pc(), manager.machine.screens[":screen"]:frame_number()))
        end
    end)

share_wr_tap = mem:install_write_tap(0x30284000, 0x3028bfff, "share_wr",
    function(offset, data, mask)
        local o = offset - 0x30284000
        if not seen_wr[o] then
            seen_wr[o] = true
            log:write(string.format("SHARE_WR off=%04x data=%08x mask=%08x pc=%08x frame=%d\n",
                o, data, mask, pc(), manager.machine.screens[":screen"]:frame_number()))
        end
    end)

-- what the C75 BIOS writes into shareram (MCU byte addr 0x4000-0xbfff)
mcu_wr_tap = mcu:install_write_tap(0x004000, 0x00bfff, "mcu_wr",
    function(offset, data, mask)
        local o = offset - 0x004000
        if not seen_mw[o] then
            seen_mw[o] = true
            log:write(string.format("MCU_WR   off=%04x data=%04x mask=%04x frame=%d\n",
                o, data, mask, manager.machine.screens[":screen"]:frame_number()))
        end
    end)

sysreg_tap = mem:install_write_tap(0x40000000, 0x4000005f, "sysreg",
    function(offset, data, mask)
        log:write(string.format("SYSREG   off=%02x data=%08x mask=%08x pc=%08x frame=%d\n",
            offset-0x40000000, data, mask, pc(), manager.machine.screens[":screen"]:frame_number()))
    end)

vregs = 0
c123_tap = mem:install_write_tap(0x30a00000, 0x30a0003f, "c123w",
    function(offset, data, mask)
        if vregs < 60 then
            vregs = vregs + 1
            log:write(string.format("C123_WR  off=%02x data=%08x mask=%08x pc=%08x frame=%d\n",
                offset-0x30a00000, data, mask, pc(), manager.machine.screens[":screen"]:frame_number()))
        end
    end)
c116regs = 0
c116_tap = mem:install_write_tap(0x30404000, 0x30407fff, "c116w",
    function(offset, data, mask)
        if c116regs < 60 then
            c116regs = c116regs + 1
            log:write(string.format("C116_WR  off=%04x data=%08x mask=%08x pc=%08x frame=%d\n",
                offset-0x30400000, data, mask, pc(), manager.machine.screens[":screen"]:frame_number()))
        end
    end)

-- per-frame PC sample + shareram input-area snapshots
local frames = 0
frame_notifier = emu.add_machine_frame_notifier(function()
    frames = frames + 1
    if frames <= 60 or frames % 30 == 0 then
        log:write(string.format("FRAME %4d pc=%08x\n", frames, pc()))
    end
    if frames == 240 or frames == 600 or frames == 1200 then
        log:write(string.format("-- shareram snapshot frame %d --\n", frames))
        for base = 0x30284000, 0x30284000+0x7fff, 16 do
            local row, nz = "", false
            for i = 0, 15 do
                local b = mem:read_u8(base+i)
                if b ~= 0 then nz = true end
                row = row .. string.format("%02x ", b)
            end
            if nz then
                log:write(string.format("%04x: %s\n", base-0x30284000, row))
            end
        end
    end
    log:flush()
end)

stop_notifier = emu.add_machine_stop_notifier(function()
    log:write("-- top polled shareram offsets --\n")
    local t = {}
    for o,c in pairs(rd_polls) do t[#t+1]={o,c} end
    table.sort(t, function(a,b) return a[2]>b[2] end)
    for i=1,math.min(#t,24) do
        log:write(string.format("off=%04x polls=%d\n", t[i][1], t[i][2]))
    end
    log:close()
end)
