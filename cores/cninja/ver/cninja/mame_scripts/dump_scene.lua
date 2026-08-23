-- Capture one video-state scene for the jtcninja NOMAIN scene replay.
--
-- dump.bin has the SAME layout for all four boards, so ver/game/rest2bin.sh
-- needs no per-game logic and the MMR SEEK offsets in jtcninja_video.v are
-- constants:
--
--   off      size    content
--   0x0000   0x0010  tilegen0 deco16ic control, words 0..7, LITTLE endian
--   0x0010   0x0010  tilegen1 deco16ic control          (jtdeco16ic_mmr)
--   0x0020   0x0005  vprio0, vprio1 (LE) + cbuster m_pri (jtframe_simdumper)
--   0x0040   0x2000  palette                    -> pal.bin
--   0x2040   0x2000  tilegen0 pf1               -> t0p1.bin
--   0x4040   0x2000  tilegen0 pf2               -> t0p2.bin
--   0x6040   0x2000  tilegen1 pf1               -> t1p1.bin
--   0x8040   0x2000  tilegen1 pf2               -> t1p2.bin
--   0xA040   0x1000  tilegen0 row/col scroll    -> rs0.bin
--   0xB040   0x1000  tilegen1 row/col scroll    -> rs1.bin
--   0xC040   0x0800  sprite RAM                 -> oram.bin
--
-- RAM images keep m68k byte order (the BRAMs load them with ENDIAN=1); the
-- register blocks are little endian because that is how mmr[] is indexed.
-- Regions smaller than their slot are zero padded, so every game fills the
-- BRAM the same way. Control registers are write-only in the deco16ic, hence
-- the write taps.
--
-- screen.png is taken inside the same notifier as dump.bin, so a scene folder
-- always holds the picture of the exact frame it captured.
--
-- Burst  : CNJ_SCENE_BASE=<dir> [CNJ_SCENE_FRAMES=first:last:step]
--          -> <dir>/<NNNN>/{dump.bin,screen.png}, default 300:3000:300
-- Single : CNJ_SCENE_OUT=<file> [CNJ_SCENE_FRAME=N], default frame 320

local mac  = manager.machine
local prog = mac.devices[":maincpu"].spaces["program"]
local BASE  = os.getenv("CNJ_SCENE_BASE")
local OUT   = os.getenv("CNJ_SCENE_OUT") or "/tmp/cnj_scene.bin"

local targets = {}
if BASE then
  local spec = os.getenv("CNJ_SCENE_FRAMES") or "300:3000:300"
  local a, b, st = spec:match("^(%d+):(%d+):(%d+)$")
  for f = tonumber(a), tonumber(b), tonumber(st) do targets[#targets+1] = f end
else
  targets[1] = tonumber(os.getenv("CNJ_SCENE_FRAME") or "320")
end

-- Per-board addresses. pal/pf/rs are { base, length } lists concatenated into
-- one slot; ctl0/ctl1 are the pf_control_w windows tapped below.
local BOARDS = {
  cninja = {
    sets = { cninja=1, cninja1=1, cninjau=1, joemac=1 },
    ctl0 = 0x140000, ctl1 = 0x150000,
    pal  = {{0x19c000,0x2000}},
    t0p1 = {{0x144000,0x1000}}, t0p2 = {{0x146000,0x1000}},
    t1p1 = {{0x154000,0x1000}}, t1p2 = {{0x156000,0x1000}},
    rs0  = {{0x14c000,0x800},{0x14e000,0x800}},
    rs1  = {{0x15c000,0x800},{0x15e000,0x800}},
    oram = {{0x1a4000,0x800}},
  },
  darkseal = {
    sets = { darkseal=1, darkseal1=1, darksealj=1, gatedoom=1, gatedoom1=1 },
    ctl0 = 0x2a0000, ctl1 = 0x240000,
    pal  = {{0x140000,0x2000}},
    t0p1 = {{0x260000,0x2000}}, t0p2 = {{0x262000,0x2000}},
    t1p1 = {{0x200000,0x2000}}, t1p2 = {{0x202000,0x2000}},
    -- one table per chip, shared by both playfields
    rs0  = {{0x220000,0x1000}}, rs1 = {{0x222000,0x1000}},
    oram = {{0x120000,0x800}},
  },
  cbuster = {
    sets = { cbuster=1, cbusterw=1, cbusterj=1, twocrude=1, twocrudea=1 },
    ctl0 = 0x0b5000, ctl1 = 0x0b6000,
    pal  = {{0x0b8000,0x2000}},
    t0p1 = {{0x0a0000,0x2000}}, t0p2 = {{0x0a2000,0x1000}},
    t1p1 = {{0x0a8000,0x1000}}, t1p2 = {{0x0aa000,0x1000}},
    rs0  = {{0x0a4000,0x800},{0x0a6000,0x800}},
    rs1  = {{0x0ac000,0x800},{0x0ae000,0x800}},
    oram = {{0x0b0000,0x800}},
  },
  edrandy = {
    sets = { edrandy=1 },
    ctl0 = 0x140000, ctl1 = 0x150000,
    pal  = {{0x188000,0x2000}},
    t0p1 = {{0x144000,0x1000}}, t0p2 = {{0x146000,0x1000}},
    t1p1 = {{0x154000,0x1000}}, t1p2 = {{0x156000,0x1000}},
    rs0  = {{0x14c000,0x800},{0x14e000,0x800}},
    rs1  = {{0x15c000,0x800},{0x15e000,0x800}},
    oram = {{0x1bc000,0x800}},
  },
  vaportra = {
    sets = { vaportra=1, vaportrau=1, kuhga=1 },
    ctl0 = 0x2c0000, ctl1 = 0x240000,
    -- the two palette halves are 0x4000 apart, not contiguous
    pal  = {{0x300000,0x1000},{0x304000,0x1000}},
    t0p1 = {{0x280000,0x2000}}, t0p2 = {{0x282000,0x2000}},
    t1p1 = {{0x200000,0x2000}}, t1p2 = {{0x202000,0x2000}},
    rs0  = {}, rs1 = {},        -- pf_update(0,0): no scroll tables
    oram = {{0x318000,0x800}},
  },
}

local setname = mac.system.name
local board
for _, b in pairs(BOARDS) do if b.sets[setname] then board = b end end
if board == nil then
  emu.print_error("dump_scene: unknown set " .. setname)
  return
end

-- deco16ic control is write only, and so is cbuster's priority PAL
local c0, c1 = {}, {}
for i = 0, 7 do c0[i] = 0; c1[i] = 0 end
local vprio0, vprio1, cbpri = 0, 0, 0

-- The tap handles MUST stay referenced: a collected passthrough handler is
-- silently removed and every register then dumps as zero. Names must be unique.
local taps = {}

-- Merge by mem_mask, like deco16ic::pf_control_w's COMBINE_DATA. edrandy writes
-- these registers one byte at a time; overwriting the whole word on every write
-- clobbers the other half and the scene replays with the wrong tile size.
local function combine(t, i, d, m)
  t[i] = ((t[i] & ~m) | (d & m)) & 0xffff
end
taps[#taps+1] = prog:install_write_tap(board.ctl0, board.ctl0 + 0xf, "cnj_ctl0",
  function(o, d, m) combine(c0, ((o - board.ctl0) >> 1) & 7, d, m); return d end)
taps[#taps+1] = prog:install_write_tap(board.ctl1, board.ctl1 + 0xf, "cnj_ctl1",
  function(o, d, m) combine(c1, ((o - board.ctl1) >> 1) & 7, d, m); return d end)
_G.__taps = taps

if board == BOARDS.vaportra then
  taps[#taps+1] = prog:install_write_tap(0x100000, 0x100003, "cnj_vprio", function(o, d, m)
    if (o & 2) == 0 then vprio0 = ((vprio0 & ~m) | (d & m)) & 0xffff
    else                 vprio1 = ((vprio1 & ~m) | (d & m)) & 0xffff end
    return d
  end)
end

if board == BOARDS.cbuster then
  -- same table as cbuster_state::prot_w
  local PRI = { [0x0e]=0, [0x00]=0, [0xf1]=1, [0x80]=1, [0x40]=1, [0xc0]=0, [0xff]=1 }
  taps[#taps+1] = prog:install_write_tap(0x0bc004, 0x0bc005, "cnj_cbpri", function(o, d)
    local p = PRI[d & 0xffff]
    if p ~= nil then cbpri = p end
    return d
  end)
end

local function u8(f, v) f:write(string.char(v & 0xff)) end
local function le16(f, v) u8(f, v); u8(f, v >> 8) end
local function pad(f, n) for _ = 1, n do u8(f, 0) end end

-- write the concatenated regions, then zero pad up to `slot` bytes
local function region(f, list, slot)
  local n = 0
  for _, r in ipairs(list) do
    for i = 0, r[2] - 1 do u8(f, prog:read_u8(r[1] + i)) end
    n = n + r[2]
  end
  pad(f, slot - n)
end

local done = {}
_G.__ds = emu.add_machine_frame_notifier(function()
  local fn = mac.screens:at(1):frame_number()
  for _, t in ipairs(targets) do
    if fn >= t and not done[t] then
      done[t] = true
      local dir = BASE and string.format("%s/%04d", BASE, t) or nil
      local f = io.open(dir and (dir .. "/dump.bin") or OUT, "wb")
      if not f then
        emu.print_error("dump_scene: cannot write scene " .. t)
        return
      end
      for i = 0, 7 do le16(f, c0[i]) end
      for i = 0, 7 do le16(f, c1[i]) end
      le16(f, vprio0); le16(f, vprio1); u8(f, cbpri)
      pad(f, 0x40 - 0x25)
      region(f, board.pal,  0x2000)
      region(f, board.t0p1, 0x2000)
      region(f, board.t0p2, 0x2000)
      region(f, board.t1p1, 0x2000)
      region(f, board.t1p2, 0x2000)
      region(f, board.rs0,  0x1000)
      region(f, board.rs1,  0x1000)
      region(f, board.oram, 0x0800)
      f:close()
      if dir then mac.screens:at(1):snapshot(dir .. "/screen.png") end
      emu.print_info(string.format(
        "SCENE %s %04d at fn=%d (tg0 scr %04x/%04x %04x/%04x, tg1 %04x/%04x %04x/%04x)",
        setname, t, fn, c0[1], c0[2], c0[3], c0[4], c1[1], c1[2], c1[3], c1[4]))
    end
  end
end)
