-- Generic MAME Lua debugger wrapper.
--
-- Usage:
--   MAMEDBG_SCRIPT=/abs/path/to/child.lua \
--   MAMEDBG_TIMEOUT=120 \
--   MAMEDBG_DELETE="/tmp/out1;/tmp/out2" \
--   mame <system> -debug -nothrottle -sound none -autoboot_delay 0 \
--       -autoboot_script /abs/path/to/modules/jtframe/mame/mamedbg.lua
--
-- Child scripts may use the global MAMEDBG table for logging, cleanup, and
-- explicit exit control. If the child forgets to exit, this wrapper forces a
-- shutdown after MAMEDBG_TIMEOUT wall-clock seconds.

local function file_exists(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

local function split_list(str)
    local out = {}
    if not str or str == "" then
        return out
    end
    for part in string.gmatch(str, "([^;]+)") do
        out[#out + 1] = part
    end
    return out
end

local jtroot = os.getenv("JTROOT") or "."
local wrapper_dir = os.getenv("JTFRAME") and (os.getenv("JTFRAME") .. "/mame") or "."
local default_log = jtroot .. "/tasks/artifacts/mamedbg.log"

local child_script = os.getenv("MAMEDBG_SCRIPT")
local timeout_s = tonumber(os.getenv("MAMEDBG_TIMEOUT") or "120") or 120
local delete_list = split_list(os.getenv("MAMEDBG_DELETE") or "")
local log_path = os.getenv("MAMEDBG_LOG") or default_log

local cleanups = {}
local log = assert(io.open(log_path, "w"))
local exiting = false
local start_wall = os.time()

local function log_line(fmt, ...)
    if not log then
        return
    end
    log:write(string.format(fmt, ...))
    log:write("\n")
    log:flush()
end

local function run_cleanups()
    for i = #cleanups, 1, -1 do
        local ok, err = pcall(cleanups[i])
        if not ok then
            log_line("cleanup[%d] error: %s", i, tostring(err))
        end
    end
end

local function finish(reason)
    if exiting then
        return
    end
    exiting = true
    log_line("exit: %s", reason or "requested")
    run_cleanups()
    if log then
        log:flush()
        log:close()
        log = nil
    end
    manager.machine:exit()
end

_G.MAMEDBG = {
    wrapper_dir = wrapper_dir,
    jtroot = jtroot,
    child_script = child_script,
    timeout_s = timeout_s,
    log_path = log_path,
    log = log_line,
    exit = finish,
    add_cleanup = function(fn)
        cleanups[#cleanups + 1] = fn
    end,
    delete_file = function(path)
        if path and path ~= "" then
            os.remove(path)
        end
    end,
    delete_files = function(paths)
        for _, path in ipairs(paths or {}) do
            if path and path ~= "" then
                os.remove(path)
            end
        end
    end
}

emu.add_machine_stop_notifier(function()
    if log then
        run_cleanups()
        log:flush()
        log:close()
        log = nil
    end
end)

emu.register_periodic(function()
    if exiting then
        return
    end
    if timeout_s > 0 and (os.time() - start_wall) >= timeout_s then
        log_line("timeout after %d wall-clock seconds", timeout_s)
        finish("timeout")
    end
end)

for _, path in ipairs(delete_list) do
    if file_exists(path) then
        os.remove(path)
        log_line("deleted stale file: %s", path)
    end
end

if not child_script or child_script == "" then
    log_line("missing MAMEDBG_SCRIPT")
    finish("missing child")
else
    log_line("wrapper=%s", wrapper_dir)
    log_line("child=%s", child_script)
    log_line("timeout=%d", timeout_s)
    local ok, err = xpcall(function()
        dofile(child_script)
    end, function(err)
        return tostring(err)
    end)
    if not ok then
        log_line("child error:\n%s", tostring(err))
        finish("child error")
    end
end
