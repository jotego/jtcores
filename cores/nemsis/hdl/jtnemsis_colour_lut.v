/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2026.
SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
SPDX-License-Identifier: GPL-3.0-only
Date: 2026-11-08

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

*/

//================================================================================
//  Colour Look-Up-Table
//  
//  Probalby loosely based on jtframe_dual_ram.
//================================================================================

// Triple-port RAM to convert palette values to RGB values, typically used to
// simulate a resistor network.

// parameters:
//      PW      => Palette bit width
//      CW      => Colour width
//      SYNFILE => hexadecimal file to load for synthesis

`default_nettype none

module jtnemsis_colour_lut #( parameter PW=5, CW=8, SYNFILE="" )(
    input      clk,
    input      [PW-1:0] in_red,
    input      [PW-1:0] in_green,
    input      [PW-1:0] in_blue,
    output reg [CW-1:0] out_red,
    output reg [CW-1:0] out_green,
    output reg [CW-1:0] out_blue
);

(* ramstyle = "no_rw_check" *) reg [CW-1:0] lut[0:(2**PW)-1];

// file for synthesis:
/* verilator lint_off WIDTH */
initial begin
	if( SYNFILE != "" ) $readmemh( SYNFILE, lut );
end
/* verilator lint_on WIDTH */

always @(posedge clk) begin
    out_red   <= lut[ in_red   ];
    out_green <= lut[ in_green ];
    out_blue  <= lut[ in_blue  ];
end

endmodule
