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

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 18-9-2026
*/

// sequential multiply/divide unit, no DSP primitives
// mul: 16 cycles radix-4 shift-add. div: 64 cycles restoring, 64/32 for ediv
// division by zero returns zero, matching MAME's divo hack

module jt960_muldiv(
    input             rst,
    input             clk,
    input             cen,
    input             start,
    input      [ 2:0] op,
    input      [31:0] s1, s2, s2h,
    output reg [31:0] r0, r1,      // r0=dst, r1=dst+1 (emul hi / ediv quotient)
    output reg        busy,
    output reg        done         // 1-cen pulse
);

`include "i960/jt960.vh"

reg  [63:0] p;     // mul accumulator / dividend & quotient
reg  [32:0] rem;
reg  [31:0] v, s1l;
reg  [33:0] v3;
reg  [ 6:0] cntr;
reg  [ 2:0] opl;
reg         sgnq, sgnr, ismul, fin;

wire [33:0] mulp = p[1:0]==2'd0 ? 34'd0 : p[1:0]==2'd1 ? {2'd0, v} :
                   p[1:0]==2'd2 ? {1'b0, v, 1'b0} : v3;
wire [33:0] muls = {2'b0, p[63:32]} + mulp;
wire [32:0] shft = {rem[31:0], p[63]};
wire [32:0] rsub = shft - {1'b0, v};
wire        isgn = op==MD_DIVI || op==MD_REMI || op==MD_MODI;
wire [31:0] abs1 = (isgn && s1[31]) ? ~s1+32'd1 : s1;
wire [31:0] abs2 = (isgn && s2[31]) ? ~s2+32'd1 : s2;
wire [31:0] qneg = ~p[31:0]+32'd1;
wire [31:0] rneg = ~rem[31:0]+32'd1;
wire [31:0] rfix = sgnr ? rneg : rem[31:0];

always @(posedge clk) begin
    if( rst ) begin
        busy<=0; done<=0; r0<=0; r1<=0; fin<=0;
        p<=64'd0; v<=0; rem<=0; cntr<=0; opl<=0;
        sgnq<=0; sgnr<=0; ismul<=0; s1l<=0; v3<=0;
    end else if( cen ) begin
        done <= 0;
        if( start ) begin
            opl   <= op;
            s1l   <= s1;
            cntr  <= 0;
            rem   <= 33'd0;
            fin   <= 0;
            sgnq  <= isgn && (s1[31]^s2[31]);
            sgnr  <= isgn && s2[31];
            ismul <= op==MD_MUL || op==MD_EMUL;
            case( op )
            MD_MUL, MD_EMUL: begin
                p <= {32'd0, s2}; v <= s1;   busy <= 1;
                v3 <= {2'd0, s1} + {1'b0, s1, 1'b0};
            end
            MD_EDIV: begin
                p <= {s2h, s2};   v <= s1;   busy <= s1!=0;
                if( s1==0 ) begin done<=1; r0<=0; r1<=0; end
            end
            MD_DIVO, MD_REMO: begin
                p <= {32'd0, s2}; v <= s1;   busy <= s1!=0;
                if( s1==0 ) begin done<=1; r0<=0; r1<=0; end
            end
            default: begin // signed divi/remi/modi
                p <= {32'd0, abs2}; v <= abs1; busy <= abs1!=0;
                if( abs1==0 ) begin done<=1; r0<=0; r1<=0; end
            end
            endcase
        end else if( busy ) begin
            if( fin ) begin
                busy <= 0;
                done <= 1;
                fin  <= 0;
                case( opl )
                MD_MUL:  r0 <= p[31:0];
                MD_EMUL: begin r0 <= p[31:0];   r1 <= p[63:32]; end
                MD_DIVO: r0 <= p[31:0];
                MD_REMO: r0 <= rem[31:0];
                MD_EDIV: begin r0 <= rem[31:0]; r1 <= p[31:0];  end
                MD_DIVI: r0 <= sgnq ? qneg : p[31:0];
                MD_REMI: r0 <= rfix;
                MD_MODI: r0 <= (sgnq && rfix!=0) ? rfix+s1l : rfix;
                default: r0 <= 0;
                endcase
            end else if( ismul ) begin
                p    <= {muls, p[31:2]};
                cntr <= cntr + 7'd1;
                if( cntr==7'd15 ) fin <= 1;
            end else begin
                if( !rsub[32] ) begin
                    rem <= rsub;
                    p   <= {p[62:0], 1'b1};
                end else begin
                    rem <= shft;
                    p   <= {p[62:0], 1'b0};
                end
                cntr <= cntr + 7'd1;
                if( cntr==7'd63 ) fin <= 1;
            end
        end
    end
end

endmodule
