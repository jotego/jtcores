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
    Date: 4-12-2023 */
/* verilator coverage_off */
module jt6805_regs(
    input             rst,
    input             clk,
    input             cen,
    output reg [12:0] md,
    // interrupts
    input      [ 2:0] iv,
    input             irq,
    // CONTROL
    input             branch,
    input             brlatch,
    input             fetch,
    input             inc_pc,
    input             md_shift,
    input             op0inv,
    input             wr,
    input      [ 1:0] brt_sel,
    input      [ 1:0] ea_sel,
    input      [ 1:0] opnd_sel,
    input      [ 2:0] ld_sel,
    input      [ 3:0] cc_sel,
    input      [ 3:0] rmux_sel,
    // ALU
    input      [12:0] rslt,
    input             rslt_h,
    input      [ 2:0] rslt_cc,
    output reg [12:0] op0, op1,
    output reg        h,c,i,
    // external bus
    input      [ 7:0] din,
    output reg [12:0] addr, // always valid
    output reg [ 7:0] dout
);

`include "6805_param.vh"

reg  [ 7:0] a, x;
reg  [ 5:0] s;
reg  [12:0] rmux, ea, pc;
reg         n,z; // other condition codes
reg         brok;

`ifdef SIMULATION
wire [4:0] cc = {h,i,n,z,c};
`endif

always @* begin
    case( rmux_sel )
           A_RMUX: rmux = { 5'd0, a };
           X_RMUX: rmux = { 5'd0, x };
           S_RMUX: rmux = { 7'd1, s };
          PC_RMUX: rmux = pc;
          EA_RMUX: rmux = ea;
          CC_RMUX: rmux = {8'd0, h,i,n,z,c};
         ONE_RMUX: rmux = 13'd1;
        ZERO_RMUX: rmux = 13'd0;
          IV_RMUX: rmux = {9'h1ff,iv,1'b0};
          default: rmux = md;
    endcase
    case( ea_sel )
        S_EA: addr = { 7'd1, s };
        M_EA: addr = ea;
        default: addr = pc;
    endcase
    dout = md_shift ? {3'd0,md[12:8]} : md[7:0];
end

always @( posedge clk, posedge rst ) begin
    if( rst ) begin
        a   <= 0;
        x   <= 0;
        s   <= 0;
        op0 <= 0;
        op1 <= 0;
        md  <= 0;
        ea  <= 0;
        {h,n,z,c} <= 0;
        i    <= 1;
    end else if( cen ) begin
        if( fetch  ) begin
            md[ 7:0] <= din;
            md[12:8] <= md_shift ? md[4:0] : 5'd0;
        end
        if( branch ) md[12:8] <= {5{md[7]}}; // sign extension for BR instructions
        case( opnd_sel )
            LD0_OPND: op0 <= {13{op0inv}} ^ rmux;
            LD1_OPND: op1 <= rmux;
            default:;
        endcase
        case( cc_sel )
              NZ_CC:    {n,z  } <= rslt_cc[2:1];
             NZC_CC:    {n,z,c} <= rslt_cc;
            NZC1_CC:    {n,z,c} <= {rslt_cc[2:1],1'b1};
            N0Z1_CC:    {n,z  } <= 2'b01;
              I0_CC:  i         <= 0;
              I1_CC:  i         <= 1;
            HNZC_CC:  {h,n,z,c} <= {rslt_h, rslt_cc};
               C_CC:         c  <= rslt_cc[0];
              C0_CC:         c  <= 0;
              C1_CC:         c  <= 1;
            default:;
        endcase
        case( ld_sel )
              A_LD:     a <= rslt[7:0];
              X_LD:     x <= rslt[7:0];
              S_LD:     s <= rslt[5:0];
             MD_LD:    md <= rslt;
             EA_LD:    ea <= rslt;
             CC_LD:    {h,i,n,z,c} <= rslt[4:0];
             PC_LD: if( (brok && branch) || (!branch && brt_sel==0) || (brt_sel==CLR_BRT && !c) || (brt_sel==SET_BRT && c))
                        pc <= rslt;
             default:;
        endcase
        if( inc_pc ) pc <= pc+13'd1;
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        brok <= 0;
    end else if(cen) begin
        if( brlatch ) case(md[3:0])
            4'b0000: brok <= 1; // bra
            4'b0001: brok <= 0; // brn
            4'b0010: brok <= !(c | z); // bhi
            4'b0011: brok <=   c | z;  // bls
            4'b0100: brok <= ! c; // bcc/bhs
            4'b0101: brok <=   c; // bcs/blo
            4'b0110: brok <= ! z; // bne
            4'b0111: brok <=   z; // beq
            4'b1000: brok <= ! h; // bhc
            4'b1001: brok <=   h; // bhs
            4'b1010: brok <= ! n; // bpl
            4'b1011: brok <=   n; // bmi
            4'b1100: brok <= ! i; // bmc
            4'b1101: brok <=   i; // bms
            4'b1110: brok <= irq; // int. line active
            4'b1111: brok <=~irq; // int. line clear
        endcase
    end
end

endmodule