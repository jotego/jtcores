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
    input      [ 7:0] md,
    input             op0_inv,
    input      [15:0] rslt,
    input             rslt_h,
    input      [ 3:0] rslt_cc,
    output reg [15:0] op0, op1,
    // control
    // external bus
    input      [ 7:0] din
    output reg [15:0] addr, // always valid
    output reg [ 7:0] dout
);

`include "jt680x.vh"

reg  [ 7:0] acca, accb;
reg         i,h,n,z,v,c; // condition codes
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
    addr = use_ea   ? ea : pc;
    dout = md_shift ? md[15:8] : md[7:0];
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
        {h,n,z,v,c} <= 0;
        i    <= 1;
    end if( cen ) begin
        if( fetch  ) begin
            md[ 7:0] <= din;
            md[15:8] <= md_shift ? md[7:0] : 8'd0;
        end
        case( opnd_ctrl )
            LD0_OPND: op0 <= {16{op0_inv}} ^ rmux;
            LD1_OPND: op1 <= rmux;
            default:;
        endcase
        case( cc_ctrl )
             NZVC_CC:    {n,z,v,c} <= rslt_cc;
            N0ZVC_CC:    {n,z,v,c} <= {1'b0,rslt_cc[2:0]};
              NZV_CC:    {n,z,v  } <= rslt_cc[3:1];
                Z_CC:       z      <= rslt_cc[2];
                C_CC:           c  <= rslt_cc[0];
             NZV0_CC:    {n,z,v  } <= {rslt_cc[3:2],1'b0};
            N0Z1V0C0_CC: {n,z,v,c} <= 4'b0100;
            NZV0C1_CC:   {n,z,v,c} <= {rslt_cc[3:2],2'b01};
            NZV0C0_CC:   {n,z,v,c} <= {rslt_cc[3:2],2'b00};
            HNZVC_CC:  {h,n,z,v,c} <= {rslt_h, rslt_cc};
               I0_CC:  i           <= 0;
               I1_CC:  i           <= 1;
               C0_CC:           c  <= 0;
               C1_CC:           c  <= 1;
               V0_CC:         v    <= 0;
               V1_CC:         v    <= 1;
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

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        branch <= 0;
    end else if(cen) begin
        if( ld_branch ) case(sel)
            4'b0000: branch <= 1; // bra
            4'b0001: branch <= 0; // brn
            4'b0010: branch <= !(c | z); // bhi
            4'b0011: branch <=   c | z;  // bls
            4'b0100: branch <= ! c; // bcc/bhs
            4'b0101: branch <=   c; // bcs/blo
            4'b0110: branch <= ! z; // bne
            4'b0111: branch <=   z; // beq
            4'b1000: branch <= ! v; // bvc
            4'b1001: branch <=   v; // bvs
            4'b1010: branch <= ! n; // bpl
            4'b1011: branch <=   n; // bmi
            4'b1100: branch <= !(n ^ v); // bge
            4'b1101: branch <=   n ^ v;  // blt
            4'b1110: branch <= !(z | (n ^ v)); // bgt
            4'b1111: branch <=   z | (n ^ v);// ble
        endcase
    end
end

endmodule