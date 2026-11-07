/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package cfgstr

import(
    "slices"
    "jotego/jtframe/macros"
)

type Config struct {
	Target,
	Core,
	Output,
	Template string
	Add     []string // new definitions in command line
	Discard []string // definitions to be discarded
}

func (cfg *Config)SetReleaseMode() {
    if !slices.Contains(cfg.Add,macros.JTFRAME_RELEASE) {
        cfg.Add=append(cfg.Add,macros.JTFRAME_RELEASE)
    }
}