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
    input      [ 2:0] acca_ctrl, accb_ctrl, ix_ctrl,
                      op0_sel,   op1_sel,
    input      [ 1:0] cc_ctrl,
    input             load_sp
);

`include "jt680x.vh"

reg  [ 7:0] acca, accb, cc;
reg  [15:0] xreg, sp;

always @* begin
    case( op0_sel )
        ACCA_OP0:     op0 = { 8'd0, acca };
        ACCB_OP0:     op0 = { 8'd0, accb };
        ACCD_OP0:     op0 = { acca, accb };
        IX_OP0:       op0 = xreg;
        SP_OP0:       op0 = sp;
        default:      op0 = md;
    endcase
    case (op1_ctrl)
        ZERO_OP1:     op1 = 0;
        PLUS_ONE_OP1: op1 = 1;
        ACCB_OP1:     op1 = { 8'd0, accb };
        MDHI_OP1:     op1 = { 8'd0, md[15:8] };
        default:      op1 = md;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        acca <= 0;
        accb <= 0;
        xreg <= 0;
        sp   <= 0;
        cc   <= 8'hc0;
    end if(cen) begin
        case( acca_ctrl )
            LOAD_ACCA:    acca <= rslt[7:0];
            LOAD_HI_ACCA: acca <= rslt[15:8];
            XCG_ACCA:     acca <= xreg[15:8];
            PULL_ACCA:    acca <= din;
            default:;
        endcase
        case( accb_ctrl )
            LOAD_ACCB:    accb <= rslt[7:0];
            XCG_ACCB:     accb <= xreg[7:0];
            PULL_ACCB:    accb <= din;
            default:;
        endcase
        case( ix_ctrl )
            LOAD_IX:      xreg <= rslt[15:0];
            XCG_IX:       xreg <= { acca, accb };
            PULL_HI_IX:   xreg[15:8] <= din;
            PULL_LO_IX:   xreg[ 7:0] <= din;
            default:;
        endcase
        case (cc_ctrl)
            LOAD_CC:      cc <= cc_out;
            PULL_CC:      cc <= data_in;
            default:;
        endcase
        if( load_sp ) sp <= rslt;
    end
end

endmodule