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
    Date: 21-1-2023 */

package cmd

import (
	"fmt"
	"github.com/spf13/cobra"

	"jotego/jtframe/mmr"
	. "jotego/jtframe/common"
)

func init() {
	var mmrCmd = &cobra.Command{
		Use:   "mmr [core-name]",
		Short: "Generate verilog modules for memory mapped registers",
		Long: mmr_help,
		Run: func(cmd *cobra.Command, args []string) {
			var e error
			var corename string
			corename, e = get_corename(args)
			Must(e)
			mmrpath := mmr.GetMMRPath(corename)
			if FileExists(mmrpath) {
				Must(mmr.Generate(corename, verbose))
			} else if verbose {
				fmt.Printf("Skipping MMR for core %s (%s not present)\n",corename,mmrpath)
			}
		},
		Args: cobra.MaximumNArgs(1),
	}

	rootCmd.AddCommand(mmrCmd)
}

const mmr_help=`Generate memory-mapped register Verilog modules from core cfg/mmr.yaml.

Each mmr.yaml entry defines one MMR block:
  - name (required): block name; output module is jt<core>_<name>_mmr.v.
    If no_core_name: true, module is jt<name>_mmr.v instead.
  - size (required): number of bytes in the internal mmr[] array (must be >= 4).
  - dw (optional): bus width for host access, 8 (default) or 16.
    dw: 16 enables a 16-bit din/dout interface with dsn byte strobes.
  - read_only (optional): when true, write handling and dout output are omitted.
  - regs (required): exported register signals.

Each regs item supports:
  - name (required): output signal name.
  - dw (required unless wr_event is true): output signal width.
  - at (required): byte/bit mapping into mmr[].
    Formats: N, N[B], N[MSB:LSB], or a comma-separated list of these.
    Example: "0x10[7:0], 0x11[3:0]".
  - wr_event (optional): generate a one-clock pulse on write to the first "at" address.
    If wr_event is true and dw is omitted/0, it is treated as event-only (no bit mapping).
  - desc (optional): metadata only; not used in code generation.

The command reads $CORES/<core>/cfg/mmr.yaml and renders $JTFRAME/hdl/inc/mmr.v
template into $CORES/<core>/hdl/*.v files.`