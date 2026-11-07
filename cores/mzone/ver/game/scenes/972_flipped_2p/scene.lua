-- SPDX-License-Identifier: GPL-3.0-or-later
-- Preserve the documented two-player input sequence in 972_flipped_2p.lua.
local coin1, coin2, start2
return {
    frame = 972,
    initialize = function(machine)
        local ports = type(machine.ioport)=="function" and machine:ioport().ports or machine.ioport.ports
        local in0 = ports[":IN0"]
        coin1 = in0:field(0x01)
        coin2 = in0:field(0x02)
        start2 = in0:field(0x10)
        ports[":DSW2"]:field(0x04):set_value(4) -- cocktail cabinet
    end,
    update = function(_, frame)
        if frame==355 then coin1:set_value(1); coin2:set_value(1) end
        if frame==356 then coin1:set_value(0); coin2:set_value(0) end
        if frame==369 then start2:set_value(1) end
        if frame==370 then start2:set_value(0) end
    end
}
