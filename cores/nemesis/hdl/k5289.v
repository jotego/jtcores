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
//  K0005289 Pre-SCC Wavetable Sound Generator
//================================================================================

/*

CUSTOM CHIP pinout:

          _____________
        _|             |_
GND(0) |_|1          42|_| VCC
        _|             |_                     
A(0)   |_|2          41|_| /RESET
        _|             |_
A(1)   |_|3          40|_| 1QE(4)
        _|             |_
A(2)   |_|4          39|_| 1QD(3)
        _|             |_
A(3)   |_|5          38|_| 1QC(2)
        _|             |_
A(4)   |_|6          37|_| 1QB(1)
        _|             |_
A(5)   |_|7          36|_| 1QA(0)
        _|             |_
A(6)   |_|8          35|_| 2QE(4)
        _|             |_
A(7)   |_|9          34|_| 2QD(3)
        _|             |_                     
A(8)   |_|10   8A    33|_| 2QC(2)
        _|             |_
A(9)   |_|11         32|_| 2QB(1)
        _|             |_
A(10)  |_|12         31|_| 2QA(0)
        _|             |_
A(11)  |_|13         30|_| T1(connect to gnd)
        _|             |_
CLK()  |_|14         29|_| T0(connect to gnd)
        _|             |_
LD1()  |_|15         28|_| 
        _|             |_
TG1()  |_|16         27|_| 
        _|             |_
LD2()  |_|17         26|_| 
        _|             |_
TG2()  |_|18         25|_| 
        _|             |_
       |_|19         24|_| 
        _|             |_
       |_|20         23|_| 
        _|             |_
GND    |_|21         22|_| GND
         |_____________|

*/

`default_nettype none

module K005289
(
	input               i_RST_n,          // RESET signal
	input               i_CLK,            // Main clock
	input               i_CEN,            // Clock enable

	input               i_LD1,            // 
	input               i_TG1,            //

	input               i_LD2,            //
	input               i_TG2,            //

	input     [11:0]    i_COUNTER,        // 12 bits input counter to play frequency

	output     [4:0]    o_Q1,             // 5 bits output
	output     [4:0]    o_Q2              // 5 bits output
);

////////////////////////////////////////////////////////////////////////////////////////////////////

wire      [11:0]    addrLD1, addrTG1, addrLD2, addrTG2;

// the 17 bits counters will serve 2 purposes count on the lower part on 12 bits and output
// the accumulated upper 5 bits part
reg	      [16:0]    r_count1, r_count2;

////////////////////////////////////////////////////////////////////////////////////////////////////
// Channel 1 LATCH


bus_ff #( .W( 12 ) ) ch1_ld_latch(
	.rst     ( ~i_RST_n     ),
	.clk     ( i_CLK        ),
	.trig    ( ~i_LD1       ),
	.d       ( i_COUNTER    ),
	.q       ( addrLD1      ),
	.q_n     (              )
);

bus_ff #( .W( 12 ) ) ch1_tg_latch(
	.rst     ( ~i_RST_n     ),
	.clk     ( i_CLK        ),
	.trig    ( ~i_TG1       ),
	.d       ( addrLD1      ),
	.q       ( addrTG1      ),
	.q_n     (              )
);

// Channel 2 LATCH

bus_ff #( .W( 12 ) ) ch2_ld_latch(
	.rst     ( ~i_RST_n     ),
	.clk     ( i_CLK        ),
	.trig    ( ~i_LD2       ),
	.d       ( i_COUNTER    ),
	.q       ( addrLD2      ),
	.q_n     (              )
);

bus_ff #( .W( 12 ) ) ch2_tg_latch(
	.rst     ( ~i_RST_n     ),
	.clk     ( i_CLK        ),
	.trig    ( ~i_TG2       ),
	.d       ( addrLD2      ),
	.q       ( addrTG2      ),
	.q_n     (              )
);


////////////////////////////////////////////////////////////////////////////////////////////////////
// Channel 1 COUNTERS
//
// addrTG1  = IN  : 12 bits data input
// i_CLK    = IN  : clock input
// i_CEN    = IN  : clock enable
// i_RST_n  = IN  : reset at 0

/*

Off-By-One Correction

As reported by Ace in note No.10903 of https://mametesters.org/view.php?id=3539, in order
for the pitch to be accurate, the counters must be preset to TG1 + 1 (or TG2 + 1). It seems
counter-intuitive to add this bit of complexity to an otherwise simple design, instead of
just using another value in the audio player, but it makes sense if you thing about the fact
that this correction allows you to use the same value for the 5289 and the AY-3-8910s, and
it will play the same note.

*/

reg [6:0] cen_cnt;

always @( posedge i_CLK ) begin
	if (~i_RST_n) begin // if n_reset = 0
		r_count1 <=  17'd0;                       // 12 bits + 5 bits for the counter output
		r_count2 <=  17'd0;                       // 12 bits + 5 bits for the counter output
		cen_cnt  <=  7'd0;
	end else if (i_CEN) begin                     // if i_CEN pulse = 1
		cen_cnt <= cen_cnt + 7'd1;
	
		// COUNTER 1
		if(r_count1[11:0] == 12'hFFF) begin
			r_count1 <= r_count1 + 17'd1;         // we need to add 1 before the re-set of the lower value to be sure we increment the upper part for the output
			r_count1[11:0] <= addrTG1 + 12'd1;    // off-by-one correction, see comment above
		end else begin
			r_count1 <= r_count1 + 17'd1;
		end

		// COUNTER 2
		if(r_count2[11:0] == 12'hFFF) begin
			r_count2 <= r_count2 + 17'd1;         // we need to add 1 before the re-set of the lower value to be sure we increment the upper part for the output
			r_count2[11:0] <= addrTG2 + 12'd1;    // off-by-one correction, see comment above
		end else begin
			r_count2 <= r_count2 + 17'd1;
		end
	end
end

assign o_Q1 = r_count1[16:12];                   // we output only the upper part of the counter
assign o_Q2 = r_count2[16:12];                   // we output only the upper part of the counter

endmodule
