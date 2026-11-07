/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package mem

import(
    "jotego/jtframe/macros"
)

func (item *BRAMBus_Ioctl) Enabled() bool {
    aux := macros.MacroEnabled{
        When: item.When,
        Unless: item.Unless,
    }
    return aux.Enabled()
}

func (item *BRAMBus) Enabled() bool {
    aux := macros.MacroEnabled{
        When: item.When,
        Unless: item.Unless,
    }
    return aux.Enabled()
}

func (item *SDRAMBus) Enabled() bool {
    aux := macros.MacroEnabled{
        When: item.When,
        Unless: item.Unless,
    }
    return aux.Enabled()
}

func (item *SDRAMCacheLine) Enabled() bool {
    aux := macros.MacroEnabled{
        When: item.When,
        Unless: item.Unless,
    }
    return aux.Enabled()
}

func (item *SDRAMCacheCfgSelect) Enabled() bool {
    aux := macros.MacroEnabled{
        When: item.When,
        Unless: item.Unless,
    }
    return aux.Enabled()
}

func (cfg *MemConfig)calc_prom_we() {
    offset := 0
    for k,_ := range cfg.BRAM {
        bram := &cfg.BRAM[k]
        if !bram.Prom { continue }
        bram.PROM_offset = offset
        offset += 1<<bram.Addr_width
    }
}
