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
//  Sound Debugging Utility Module (omitted in releases)
//================================================================================

`default_nettype none

module nemesis_sound_debug(
	input      [ 4:0]  i_command,
	input      [ 2:0]  i_channels,
	input      [ 3:0]  i_vol_prom,
	input      [ 3:0]  i_vol_ay7,
	input      [ 3:0]  i_vol_ay8,

	// sound command
	output reg [ 7:0]  o_sound_data,
	
	// sound channels
	output reg         o_prom1_on,
	output reg         o_prom2_on,
	output reg         o_ay7_on,
	output reg         o_ay8_on,
	
	// balance
	output reg [ 7:0]  o_bal_prom,
	output reg [ 7:0]  o_bal_ay7, // AY2 from MAME
	output reg [ 7:0]  o_bal_ay8  // AY1 from MAME
);

always @(*) begin
	case( i_command )
		5'h00   : o_sound_data <= 8'h81; // Big Core Explode
		5'h01   : o_sound_data <= 8'h01; // Player Shot
		5'h02   : o_sound_data <= 8'h02; // Laser
		5'h03   : o_sound_data <= 8'h03; // Small Laser 2
		5'h04   : o_sound_data <= 8'h1A; // Catch Option
		5'h05   : o_sound_data <= 8'h12; // Catch Blue Orb
		5'h06   : o_sound_data <= 8'h08; // Zako Death
		5'h07   : o_sound_data <= 8'h0C; // Destroy Ground Enemy
		5'h08   : o_sound_data <= 8'h24; // Bibibiip
		5'h09   : o_sound_data <= 8'h40; // Credit
		5'h0A   : o_sound_data <= 8'h41; // Kuuchuusen
		5'h0B   : o_sound_data <= 8'h4B; // Level 1
		5'h0C   : o_sound_data <= 8'h42; // Level 2
		5'h0D   : o_sound_data <= 8'h44; // Level 3
		5'h0E   : o_sound_data <= 8'h45; // Level 4
		5'h0F   : o_sound_data <= 8'h43; // Level 6
		5'h10   : o_sound_data <= 8'h46; // Hidden Extra Song
		5'h11   : o_sound_data <= 8'h47; // Tutututut
		5'h12   : o_sound_data <= 8'h48; // Game Over
		5'h13   : o_sound_data <= 8'h49; // Boss
		5'h14   : o_sound_data <= 8'h4A; // High Score
		5'h15   : o_sound_data <= 8'h00; // Music Off
		5'h16   : o_sound_data <= 8'h82; // Unknown
		5'h17   : o_sound_data <= 8'h35; // Unknown
		5'h18   : o_sound_data <= 8'h0A; // Unknown
		default : o_sound_data <= 8'h00;
	endcase
end

// All,Prom-1+2+AY7,AY-8,AY-7,Prom1,Prom2,Prom-1+2,AY-7+8
always @(*) begin
	case( i_channels )
		3'd0    :   begin  o_prom1_on <= 1'b1;  o_prom2_on <= 1'b1;  o_ay7_on <= 1'b1;  o_ay8_on <= 1'b1;   end // ALL
		3'd1    :   begin  o_prom1_on <= 1'b1;  o_prom2_on <= 1'b1;  o_ay7_on <= 1'b1;  o_ay8_on <= 1'b0;   end // PROM 1+2+AY7
		3'd2    :   begin  o_prom1_on <= 1'b0;  o_prom2_on <= 1'b0;  o_ay7_on <= 1'b0;  o_ay8_on <= 1'b1;   end // AY8
		3'd3    :   begin  o_prom1_on <= 1'b0;  o_prom2_on <= 1'b0;  o_ay7_on <= 1'b1;  o_ay8_on <= 1'b0;   end // AY7
		3'd4    :   begin  o_prom1_on <= 1'b1;  o_prom2_on <= 1'b0;  o_ay7_on <= 1'b0;  o_ay8_on <= 1'b0;   end // Prom1
		3'd5    :   begin  o_prom1_on <= 1'b0;  o_prom2_on <= 1'b1;  o_ay7_on <= 1'b0;  o_ay8_on <= 1'b0;   end // Prom2
		3'd6    :   begin  o_prom1_on <= 1'b1;  o_prom2_on <= 1'b1;  o_ay7_on <= 1'b0;  o_ay8_on <= 1'b0;   end // Prom 1+2
		3'd7    :   begin  o_prom1_on <= 1'b0;  o_prom2_on <= 1'b0;  o_ay7_on <= 1'b1;  o_ay8_on <= 1'b1;   end // AY 7+8
    endcase
end

// audio balance (use sound/vol_controls.py)
always @(*) begin
	case( i_vol_prom )
		4'd0: o_bal_prom <= 78;
		4'd1: o_bal_prom <= 80;
		4'd2: o_bal_prom <= 82;
		4'd3: o_bal_prom <= 84;
		4'd4: o_bal_prom <= 86;
		4'd5: o_bal_prom <= 88;
		4'd6: o_bal_prom <= 90;
		4'd7: o_bal_prom <= 92;
		4'd8: o_bal_prom <= 94;
		4'd9: o_bal_prom <= 96;
		4'd10: o_bal_prom <= 98;
		4'd11: o_bal_prom <= 100;
		4'd12: o_bal_prom <= 102;
		4'd13: o_bal_prom <= 104;
		4'd14: o_bal_prom <= 106;
		4'd15: o_bal_prom <= 108;
	endcase
	case( i_vol_ay7 )
		4'd0: o_bal_ay7 <= 86;
		4'd1: o_bal_ay7 <= 88;
		4'd2: o_bal_ay7 <= 90;
		4'd3: o_bal_ay7 <= 92;
		4'd4: o_bal_ay7 <= 94;
		4'd5: o_bal_ay7 <= 96;
		4'd6: o_bal_ay7 <= 98;
		4'd7: o_bal_ay7 <= 100;
		4'd8: o_bal_ay7 <= 102;
		4'd9: o_bal_ay7 <= 104;
		4'd10: o_bal_ay7 <= 106;
		4'd11: o_bal_ay7 <= 108;
		4'd12: o_bal_ay7 <= 110;
		4'd13: o_bal_ay7 <= 112;
		4'd14: o_bal_ay7 <= 114;
		4'd15: o_bal_ay7 <= 116;
	endcase
	case( i_vol_ay8 )
		4'd0: o_bal_ay8 <= 118;
		4'd1: o_bal_ay8 <= 120;
		4'd2: o_bal_ay8 <= 122;
		4'd3: o_bal_ay8 <= 124;
		4'd4: o_bal_ay8 <= 126;
		4'd5: o_bal_ay8 <= 128;
		4'd6: o_bal_ay8 <= 130;
		4'd7: o_bal_ay8 <= 132;
		4'd8: o_bal_ay8 <= 134;
		4'd9: o_bal_ay8 <= 136;
		4'd10: o_bal_ay8 <= 138;
		4'd11: o_bal_ay8 <= 140;
		4'd12: o_bal_ay8 <= 142;
		4'd13: o_bal_ay8 <= 144;
		4'd14: o_bal_ay8 <= 146;
		4'd15: o_bal_ay8 <= 148;
	endcase
end

endmodule
