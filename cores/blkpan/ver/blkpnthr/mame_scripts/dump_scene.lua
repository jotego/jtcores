-- Burst scene dump for Black Panther (Konami GX604).
--
-- Writes, per target frame, the exact files GX400A_VIDEO's SIMHEXFILE hooks and
-- the mem.yaml `pal` BRAM simfile read at sim start, so a scene can be replayed
-- into the video block with the CPU stubbed out (-d NOMAIN).
--
--   region (68000)            size   -> file
--   080000-081fff palette     4096B  -> pal.bin      (odd bytes, big-endian pairs)
--   100000-101fff colorram    4096B  -> vram2.hex    (odd bytes)
--   102000-103fff videoram    8192B  -> vram1_hi/lo.hex (even=UDS, odd=LDS)
--   120000-12ffff charram    65536B  -> charram{1,2}_{hi,lo}.hex  (A1 picks 1/2)
--   180000-180fff scroll      4096B  -> scrollram.hex (odd bytes)
--   190000-190fff spriteram   4096B  -> objram.hex    (odd bytes)

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local screen; for _,s in pairs(manager.machine.screens) do screen = s; break end

local targets = {300,600,900,1200,1800,2400,3000,3600}
local idx = 1

local function wr_hex(path, t)
    local f = io.open(path,"w")
    for i=1,#t do f:write(string.format("%02x\n", t[i])) end
    f:close()
end

local function wr_bin(path, t)
    local f = io.open(path,"wb")
    for i=1,#t do f:write(string.char(t[i])) end
    f:close()
end

local function capture(frame)
    local dir = string.format("/tmp/blkpan_scene_%05d", frame)
    os.execute("mkdir -p '"..dir.."'")

    -- palette: odd bytes, already (high,low) pairs in address order
    local pal = {}
    for a = 0x080001, 0x081fff, 2 do pal[#pal+1] = mem:read_u8(a) end
    wr_bin(dir.."/pal.bin", pal)

    -- colorram -> vram2 (low byte only)
    local v2 = {}
    for a = 0x100001, 0x101fff, 2 do v2[#v2+1] = mem:read_u8(a) end
    wr_hex(dir.."/vram2.hex", v2)

    -- videoram -> vram1_hi (even/UDS) + vram1_lo (odd/LDS)
    local v1h, v1l = {}, {}
    for a = 0x102000, 0x103fff, 2 do
        v1h[#v1h+1] = mem:read_u8(a)
        v1l[#v1l+1] = mem:read_u8(a+1)
    end
    wr_hex(dir.."/vram1_hi.hex", v1h)
    wr_hex(dir.."/vram1_lo.hex", v1l)

    -- charram: A1 selects bank 1/2, A0 selects hi/lo
    local c1h, c1l, c2h, c2l = {}, {}, {}, {}
    for a = 0x120000, 0x12ffff, 4 do
        c1h[#c1h+1] = mem:read_u8(a)
        c1l[#c1l+1] = mem:read_u8(a+1)
        c2h[#c2h+1] = mem:read_u8(a+2)
        c2l[#c2l+1] = mem:read_u8(a+3)
    end
    wr_hex(dir.."/charram1_hi.hex", c1h)
    wr_hex(dir.."/charram1_lo.hex", c1l)
    wr_hex(dir.."/charram2_hi.hex", c2h)
    wr_hex(dir.."/charram2_lo.hex", c2l)

    -- scroll + objram (low byte only)
    local sc = {}
    for a = 0x180001, 0x180fff, 2 do sc[#sc+1] = mem:read_u8(a) end
    wr_hex(dir.."/scrollram.hex", sc)

    local ob = {}
    for a = 0x190001, 0x190fff, 2 do ob[#ob+1] = mem:read_u8(a) end
    wr_hex(dir.."/objram.hex", ob)

    manager.machine.video:snapshot()
    print("SCENE dumped frame "..frame.." -> "..dir)
end

emu.register_frame_done(function()
    if idx <= #targets and screen:frame_number() >= targets[idx] then
        capture(targets[idx])
        idx = idx + 1
        if idx > #targets then manager.machine:exit() end
    end
end)
