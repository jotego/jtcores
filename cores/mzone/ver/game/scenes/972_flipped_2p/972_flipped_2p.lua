-- SPDX-License-Identifier: GPL-3.0-or-later

-- Mega Zone input sequence for scene 972_flipped_2p.
--
-- Coin 1 and Coin 2 are held during frame 356.  Start 2 is held during
-- frame 370.  register_frame runs at the end of a frame, so inputs are
-- asserted one frame before the frame in which they must be sampled.

-- MAME 0.220 exposes machine and ioport as methods.
local machine = manager:machine()
local screen = machine.screens[":screen"]
local in0 = machine:ioport().ports[":IN0"]

local coin1 = in0:field(0x01)
local coin2 = in0:field(0x02)
local start2 = in0:field(0x10)

local function drive_inputs()
    local frame = screen:frame_number()

    if frame == 355 then
        coin1:set_value(1)
        coin2:set_value(1)
    elseif frame == 356 then
        coin1:set_value(0)
        coin2:set_value(0)
    end

    if frame == 369 then
        start2:set_value(1)
    elseif frame == 370 then
        start2:set_value(0)
    end
end

emu.register_frame(drive_inputs)
