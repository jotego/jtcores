/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package picorom

// Pin snapshots from the diagnostic firmware's read-only bus_state parameter:
// "<gpio before>,<data latch>,<buffer OE>,<gpio after>" (POG GPIO map)

import (
	"fmt"
	"strconv"
	"strings"
)

type Pins struct {
	Raw     string `json:"raw"`
	Address int    `json:"address"` // A0-A16 as seen by the unit (A16 reads 0 in 64k mode)
	OEn     int    `json:"oe_n"`
	CEn     int    `json:"ce_n"`
}

// Selected tells whether the socket was being read when sampled
func (p Pins) Selected() bool { return p.OEn == 0 && p.CEn == 0 }

func DecodeBusState(raw string) (before, after Pins, e error) {
	f := strings.Split(strings.TrimSpace(raw), ",")
	if len(f) != 4 { return before, after, fmt.Errorf("unexpected bus_state %q", raw) }
	gb, e1 := strconv.ParseUint(f[0], 16, 32)
	ga, e2 := strconv.ParseUint(f[3], 16, 32)
	if e1 != nil || e2 != nil { return before, after, fmt.Errorf("malformed bus_state %q", raw) }
	return gpio_pins(raw, uint32(gb)), gpio_pins(raw, uint32(ga)), nil
}

func gpio_pins(raw string, g uint32) Pins {
	return Pins{Raw: raw, Address: int(g & 0x1FFFF), OEn: int(g>>20) & 1, CEn: int(g>>21) & 1}
}
