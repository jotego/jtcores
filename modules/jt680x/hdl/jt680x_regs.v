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
/* verilator coverage_off */
module jt680x_regs(
    input             rst,
    input             clk,
    input             cen,
    // CONTROL
    input             alt,
    input             branch,
    input             brlatch,
    input             fetch,
    input             inc_pc,
    input             md_shift,
    input             op0inv,
    input      [ 1:0] ea_sel,
    input      [ 1:0] opnd_sel,
    input      [ 3:0] ld_sel,
    input      [ 3:0] rmux_sel,
    input      [ 4:0] cc_sel,
    input      [ 3:0] iv,
    output reg [15:0] md,
    // ALU
    input      [15:0] rslt,
    input             rslt_h,
    input      [ 3:0] rslt_cc,
    output reg [15:0] op0, op1,
    output reg        h,c,i,
    // external bus
    input      [ 7:0] din,
    output reg [15:0] addr, // always valid
    output reg [ 7:0] dout
);

`include "6801_param.vh"

reg  [ 7:0] a, b, md_alt;
reg  [15:0] x, s, rmux, ea, pc;
reg         n,z,v; // other condition codes
reg         brok;

`ifdef SIMULATION
wire [7:0] cc = {2'b11,h,i,n,z,v,c};
`endif

always @* begin
    case( rmux_sel )
           A_RMUX: rmux = { 8'd0, a };
           B_RMUX: rmux = { 8'd0, b };
           D_RMUX: rmux = { a, b };
           X_RMUX: rmux = x;
           S_RMUX: rmux = s;
          PC_RMUX: rmux = pc;
          EA_RMUX: rmux = ea;
          CC_RMUX: rmux = {8'd0, 2'b11, h,i,n,z,v,c};
         ONE_RMUX: rmux = 16'd1;
        ZERO_RMUX: rmux = 16'd0;
          IV_RMUX: rmux = {11'h7ff,iv,1'b0};
          default: rmux = { md[15:8], alt ? md_alt : md[7:0] };
    endcase
    case( ea_sel )
        S_EA: addr = s;
        M_EA: addr = ea;
        default: addr = pc;
    endcase
    dout = md_shift ? md[15:8] : md[7:0];
end

always @( posedge clk, posedge rst ) begin
    if( rst ) begin
        a   <= 0;
        b   <= 0;
        x   <= 0;
        s   <= 0;
        op0 <= 0;
        op1 <= 0;
        md  <= 0;
        ea  <= 0;
        pc  <= 0;
        {h,n,z,v,c} <= 0;
        i    <= 1;
    end else if( cen ) begin
        if( fetch  ) begin
            if( alt )
                md_alt <= din;
            else begin
                md[ 7:0] <= din;
                md[15:8] <= md_shift ? md[7:0] : 8'd0;
            end
        end
        if( branch ) md[15:8] <= {8{md[7]}}; // sign extension for BR instructions
        case( opnd_sel )
            LD0_OPND: op0 <= {16{op0inv}} ^ rmux;
            LD1_OPND: op1 <= rmux;
            default:;
        endcase
        case( cc_sel )
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
        case( ld_sel )
              A_LD:     a <= rslt[7:0];
              B_LD:     b <= rslt[7:0];
              D_LD: {a,b} <= rslt;
              X_LD:     x <= rslt;
              S_LD:     s <= rslt;
             MD_LD:    md <= rslt;
             EA_LD:    ea <= rslt;
             CC_LD:    {h,i,n,z,v,c} <= rslt[5:0];
             PC_LD: if( brok | ~branch ) pc <= rslt;
             default:;
        endcase
        if( inc_pc ) pc <= pc+16'd1;
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
            4'b1000: brok <= ! v; // bvc
            4'b1001: brok <=   v; // bvs
            4'b1010: brok <= ! n; // bpl
            4'b1011: brok <=   n; // bmi
            4'b1100: brok <= !(n ^ v); // bge
            4'b1101: brok <=   n ^ v;  // blt
            4'b1110: brok <= !(z | (n ^ v)); // bgt
            4'b1111: brok <=   z | (n ^ v);// ble
        endcase
    end
end

endmodule