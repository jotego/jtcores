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
//  Delayed Pulse Generator of Configurable Length
//================================================================================

`default_nettype none

module os_pulse_gen
#( parameter DELAY=0, DURATION=1 )
(
	input      clk,
	input      trig,
	input      trig_en,
	output     pulse,
	output [ DELAY + DURATION:0 ] dl
);

reg  trig_prev = 1'b0;

reg [ DELAY + DURATION:0 ] delay_line = { DELAY + DURATION + 1 {1'b0}};

wire dl0 = trig_en ? trig & ~trig_prev : 1'b0;

always @( posedge clk ) begin
	trig_prev  <= trig;

	delay_line <= { delay_line[DELAY + DURATION - 1:0], dl0 };
end

wire [ DELAY + DURATION + 1:0 ] toto = { delay_line, dl0 };

assign dl = delay_line;
assign pulse = |{ toto[ DELAY + DURATION - 1:DELAY ] };

endmodule
