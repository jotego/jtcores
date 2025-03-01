/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 4-1-2025 */

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