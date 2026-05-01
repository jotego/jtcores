local outdir = os.getenv("ARGUS_MAME_OUT") or "."
local snap_frame = tonumber(os.getenv("ARGUS_MAME_FRAME") or "700")

local machine = manager.machine
local screen = machine.screens[":screen"]
local system = machine.ioport.ports[":SYSTEM"]
local coin1 = system:field(0x80)
local start1 = system:field(0x01)
local spriteram = machine.memory.shares[":spriteram"]
local frame_count = 0

local function set_field(field, active)
    if field then
        field:set_value(active and 1 or 0)
    end
end

local function clear_inputs()
    set_field(coin1, false)
    set_field(start1, false)
end

local function dump_sprites(frame)
    local path = string.format("%s/mame_argus_spr_%05d.txt", outdir, frame)
    local f = assert(io.open(path, "w"))
    for offs = 0, 0x600 - 16, 16 do
        local sy = spriteram:read_u8(offs + 11)
        local sx = spriteram:read_u8(offs + 12)
        local attr = spriteram:read_u8(offs + 13)
        local code = spriteram:read_u8(offs + 14)
        local color = spriteram:read_u8(offs + 15)
        if not (color == 0 and sy == 0xf0) then
            f:write(string.format("%03x: sy=%02x sx=%02x attr=%02x code=%02x color=%02x\n",
                offs, sy, sx, attr, code, color))
        end
    end
    f:close()
end

emu.register_frame_done(function()
    frame_count = frame_count + 1
    local frame = frame_count

    clear_inputs()
    if frame >= 180 and frame < 184 then
        set_field(coin1, true)
    end
    if frame >= 224 and frame < 228 then
        set_field(start1, true)
    end

    if frame == snap_frame then
        local snap = string.format("%s/mame_argus_%05d.png", outdir, frame)
        screen:snapshot(snap)
        dump_sprites(frame)
        machine:exit()
    end
end, "frame")
