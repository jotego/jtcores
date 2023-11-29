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

module jt680x_regs(
    input             rst,
    input             clk,
    input             cen,
    input      [ 7:0] din, md,
    // ALU
    input      [15:0] rslt,
    output reg [15:0] op0, op1,
    // control

);

`include "jt680x.vh"

reg  [ 7:0] acca, accb;
reg  [ 5:0] cc;
reg  [15:0] xreg, sp, rmux, md, ea, pc;


always @* begin
    case( rmux_ctrl )
          MD_RMUX: rmux = md;
           A_RMUX: rmux = { 8'd0, a };
           B_RMUX: rmux = { 8'd0, b };
           X_RMUX: rmux = x;
           S_RMUX: rmux = sp;
          CC_RMUX: rmux = {2'b11, cc};
         ONE_RMUX: rmux = 16'd1;
        ZERO_RMUX: rmux = 16'd0;
    endcase
end

always @( posedge clk, posedge rst ) begin
    if( rst ) begin
        acca <= 0;
        accb <= 0;
        xreg <= 0;
        sp   <= 0;
        op0  <= 0;
        op1  <= 0;
        md   <= 0;
        ea   <= 0;
        cc   <= 0;
    end if( cen ) begin
        if( fetch  ) begin
            md[ 7:0] <= din;
            md[15:8] <= md_shift ? md[7:0] : 8'd0;
        end
        case( opnd_ctrl )
            LD0_OPND: op0 <= rmux;
            LD1_OPND: op1 <= rmux;
            default:;
        endcase
        case( ld_ctrl )
              A_LD:     a <= rslt[7:0];
              B_LD:     b <= rslt[7:0];
              D_LD: {a,b} <= rslt;
              X_LD:     x <= rslt;
              S_LD:     s <= rslt;
             EA_LD:    ea <= rslt;
             CC_LD:    cc <= rslt[5:0];
             PC_LD: if( branch_ok | ~branch ) pc <= rslt;
             default:;
        endcase
        if( inc_pc ) pc <= pc+16'd1;
    end
end

endmodule