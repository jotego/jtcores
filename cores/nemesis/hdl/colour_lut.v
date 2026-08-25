/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2023.

Support the authors:

       Raki: https://www.patreon.com/ikamusume
    LMN-san: https://ko-fi.com/lmnsan
  OScherler: https://ko-fi.com/oscherler

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
//      pw      => Palette bit width
//      cw      => Colour width
//      synfile => hexadecimal file to load for synthesis

`default_nettype none

module colour_lut #( parameter pw=5, cw=8, synfile="" )(
    input      clk,
    input      [pw-1:0] in_red,
    input      [pw-1:0] in_green,
    input      [pw-1:0] in_blue,
    output reg [cw-1:0] out_red,
    output reg [cw-1:0] out_green,
    output reg [cw-1:0] out_blue
);

(* ramstyle = "no_rw_check" *) reg [cw-1:0] lut[0:(2**pw)-1];

// file for synthesis:
/* verilator lint_off WIDTH */
initial begin
	if( synfile != "" ) $readmemh( synfile, lut );
end
/* verilator lint_on WIDTH */

always @(posedge clk) begin
    out_red   <= lut[ in_red ];
    out_green <= lut[ in_green ];
    out_blue  <= lut[ in_blue ];
end

endmodule
