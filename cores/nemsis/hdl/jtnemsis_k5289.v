/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2026.
// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// JTCORES project edits: 2026-11-08.

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

module jtnemsis_k5289
(
	input               rst_n,    // RESET signal
	input               clk,      // Main clock
	input               sound_cen,      // Clock enable

	input               ld1,      //
	input               tg1,      //

	input               ld2,      //
	input               tg2,      //

	input     [11:0]    counter,  // 12 bits input counter to play frequency

	output     [4:0]    q1,       // 5 bits output
	output     [4:0]    q2        // 5 bits output
);

////////////////////////////////////////////////////////////////////////////////////////////////////

wire [11:0] addrLD1, addrTG1, addrLD2, addrTG2;
wire        sound_reset;
wire        ch1_load, ch1_trigger, ch2_load, ch2_trigger;
reg  [16:0] count1, count2;
reg  [6:0]  cen_cnt;

assign sound_reset = ~rst_n;
assign ch1_load    = ~ld1;
assign ch1_trigger = ~tg1;
assign ch2_load    = ~ld2;
assign ch2_trigger = ~tg2;

assign q1 = count1[16:12]; // Upper five bits are the channel output.
assign q2 = count2[16:12];

always @(posedge clk) begin
    if (~rst_n) begin
        count1 <= 17'd0;
        count2 <= 17'd0;
        cen_cnt <= 7'd0;
    end else if (sound_cen) begin
        cen_cnt <= cen_cnt + 7'd1;

        // Counter 1
        if (count1[11:0] == 12'hfff) begin
            count1 <= count1 + 17'd1;
            count1[11:0] <= addrTG1 + 12'd1; // Off-by-one correction for accurate pitch.
        end else begin
            count1 <= count1 + 17'd1;
        end

        // Counter 2
        if (count2[11:0] == 12'hfff) begin
            count2 <= count2 + 17'd1;
            count2[11:0] <= addrTG2 + 12'd1;
        end else begin
            count2 <= count2 + 17'd1;
        end
    end
end

// Channel 1 load and trigger latches.
jtnemsis_bus_ff #(.W(12)) ch1_ld_latch(
    .rst   (sound_reset),
    .clk   (clk),
    .trig  (ch1_load),
    .d     (counter),
    .q     (addrLD1),
    .q_n   ()
);

jtnemsis_bus_ff #(.W(12)) ch1_tg_latch(
    .rst   (sound_reset),
    .clk   (clk),
    .trig  (ch1_trigger),
    .d     (addrLD1),
    .q     (addrTG1),
    .q_n   ()
);

// Channel 2 load and trigger latches.
jtnemsis_bus_ff #(.W(12)) ch2_ld_latch(
    .rst   (sound_reset),
    .clk   (clk),
    .trig  (ch2_load),
    .d     (counter),
    .q     (addrLD2),
    .q_n   ()
);

jtnemsis_bus_ff #(.W(12)) ch2_tg_latch(
    .rst   (sound_reset),
    .clk   (clk),
    .trig  (ch2_trigger),
    .d     (addrLD2),
    .q     (addrTG2),
    .q_n   ()
);

endmodule
