/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 22-11-2023 */

module jt680x_seq(
);

always @* case()
	FETCH: begin
		`NI
		casez( op )
			8'h01:; // NOP
			8'h04, 8'h05:
			       begin `S0D  `LDD `LDCC end // LSRD, ASLD
			8'h06: begin            `LDCC end // TAP
			8'h07: begin       `LDA       end // TPA
			8'h08, 8'h09:
			       begin `S0X  `LDX `LDCC end //  INX, DEX
			8'h0A, 8'h0B, 8'h0C, 8'h0D, 8'h0E, 8'h0F:
			       begin            `LDCC end // CLV, SEV, CLC, SEC, CLI, SEI
			8'h10, 8'h11, 8'h1B:
				   begin       `LDA `LDCC end // SBA, CBA, ABA
			8'h16, 8'h17:
				   begin       `LDD       end // TAB, TBA
			8'h18: begin `XGDX `LDD `LDX  end // XGDX
			8'h2z: begin `IMM             end // BRANCH
			default: `BAD
		endcase
	end
	IMM: begin
		casez( op )
			8'h2z: begin `S0PC `S1MD `NOBA `BRANCH end
		endcase
	end
	BRANCH: if( branch ) `LDPC else `NI

endcase

endmodule