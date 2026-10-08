-- Template child script for modules/jtframe/mame/mamedbg.lua
--
-- Run with:
--   MAMEDBG_SCRIPT=/abs/path/to/this_file.lua \
--   MAMEDBG_TIMEOUT=120 \
--   MAMEDBG_DELETE="/abs/path/to/output1;/abs/path/to/output2" \
--   mame <system> -debug -nothrottle -sound none -autoboot_delay 0 \
--       -autoboot_script /abs/path/to/modules/jtframe/mame/mamedbg.lua
--
-- Important:
--   Always arrange stale-output cleanup before the run starts.
--   Prefer MAMEDBG_DELETE in the launch command so an old trace/log file cannot
--   be mistaken for new output if the child script fails early.
--   If you need more control, explicitly remove child-owned outputs here before
--   opening them.

local dbg = manager.machine.debugger
local cpu = manager.machine.devices[":maincpu"]

local function reg(name)
    return cpu.state[name].value
end

MAMEDBG.log("template start")

-- Example child-owned output. Even if MAMEDBG_DELETE is used in the launcher,
-- removing the file here before opening it makes the intended lifecycle clear.
local out_path = "mamedbg-template.log"
MAMEDBG.delete_file(out_path)

-- Example cleanup hook for child-owned resources:
local out = assert(io.open(out_path, "w"))
MAMEDBG.add_cleanup(function()
    if out then
        out:flush()
        out:close()
        out = nil
    end
end)

dbg:command("gni 1")
out:write(string.format("PC=%08X\n", reg("PC")))
out:flush()

MAMEDBG.exit("template done")
