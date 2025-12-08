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
    Date: 28-11-2025 */
/* verilator coverage_off */
module jt65c02_regs(
    input             rst,
    input             clk,
    input             cen,
    output reg [ 7:0] md,
    // interrupts
    input      [ 2:0] iv,
    input             irq,
    // CONTROL
    input             branch, branch_lo, ni,
    input             brlatch,
    input             fetch,
    input             inc_pc,
    input             wr,
    input             stcy, brcy,
    output reg        pcpage,
    input      [ 1:0] ea_sel,
    input      [ 1:0] opnd_sel,
    input      [ 3:0] ld_sel,
    input      [ 3:0] cc_sel,
    input      [ 3:0] rmux_sel,
    // ALU
    input      [ 7:0] rslt,
    input             rslt_h,
    input      [ 3:0] rslt_cc,
    output reg [ 7:0] op0, op1,
    output reg        h,c,i,calt,d,
    output reg        brok,
    // external bus
    input      [ 7:0] din,
    output reg [15:0] addr, // always valid
    output reg [ 7:0] dout
);

`include "65c02_param.vh"

reg  [ 7:0] a, x, y, s, rmux;
reg  [15:0] ea, pc;
reg         v,n,z; // other condition codes (b=break)

wire [7:0] cc = {n,v,2'b10,d,i,z,c};

`ifdef SIMULATION
    wire [7:0] p = cc;
`endif

always @* begin
    case( rmux_sel )
           A_RMUX: rmux = a;
           X_RMUX: rmux = x;
           Y_RMUX: rmux = y;
           S_RMUX: rmux = s;
        PCLO_RMUX: rmux = pc[ 7:0];
        PCHI_RMUX: rmux = pc[15:8];
        EALO_RMUX: rmux = ea[ 7:0];
         SEX_RMUX: rmux = {8{md[7]}};
           P_RMUX: rmux = cc;
          PB_RMUX: rmux = cc | 8'h10; // B bit set
         ONE_RMUX: rmux = 8'd1;
        ZERO_RMUX: rmux = 8'd0;
          IV_RMUX: rmux = {4'hf,iv,1'b0};
          default: rmux = md;
    endcase
    case( ea_sel )
        S_EA:  addr = { 8'd1, s };
        M_EA:  addr = ea;
        M1_EA: addr = ea+16'd1;
        default: addr = pc;
    endcase
    dout = md[7:0];
end

always @( posedge clk, posedge rst ) begin
    if( rst ) begin
        i   <= 1;   // this is the only bit set on start-up by a real NMOS 6502
        // the rest of the registers have undefined values on start up
        a   <= 0;
        x   <= 0;
        y   <= 0;
        s   <= 8'hfd; // to start up the same as MAME.
        op0 <= 0;
        op1 <= 0;
        md  <= 0;
        ea  <= 0;
        pc  <= 0;
        pcpage <= 0;
        {v,h,n,z,c,d,calt} <= 0;
    end else if( cen ) begin
        pcpage <= 0;
        if( fetch  ) begin
            md[ 7:0] <= din;
        end
        case( opnd_sel )
            LD0_OPND: op0 <= rmux;
            LD1_OPND: op1 <= rmux;
            default:;
        endcase
        case( cc_sel )
              NZ_CC:    {n,z  } <= {rslt_cc[3],rslt_cc[1]};
             XXZ_CC:    {n,v,z} <= {op0[7:6],rslt_cc[1]};
            NVZC_CC:  {n,v,z,c} <= rslt_cc;
             NZC_CC:  {n,  z,c} <= {rslt_cc[3],rslt_cc[1:0]};
               Z_CC:         z  <= rslt[1];
              I0_CC:         i  <= 0;
              I1_CC:         i  <= 1;
              V0_CC:         v  <= 0;
              D0_CC:         d  <= 0;
              D1_CC:         d  <= 1;
              C0_CC:         c  <= 0;
              C1_CC:         c  <= 1;
            default:;
        endcase
        if( stcy ) calt <= rslt_cc[0];
        if( ni   ) calt <= 0;
        case( ld_sel )
              A_LD:     a <= rslt;
              X_LD:     x <= rslt;
              Y_LD:     y <= rslt;
              S_LD:     s <= rslt;
             MD_LD:    md <= rslt;
             ZP_LD:    ea <= {8'd00,rslt};
             IV_LD:    ea <= {8'hff,rslt};
             EA16_LD:  ea <= {rslt,ea[15:8]};
             PC16_LD:  pc <= {rslt,pc[15:8]};
             EA2PC_LD: pc <= ea;
              P_LD:    {n,v,d,i,z,c} <= {rslt[7:6],rslt[3:0]};
             default:;
        endcase
        if( brok && branch ) begin
            if( branch_lo )
                pc[ 7:0] <= rslt;
            else begin
                pc[15:8] <= rslt;
                pcpage   <= pc[15:8]!=rslt;
            end
        end
        if( inc_pc ) pc <= pc+16'd1;
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        brok <= 0;
    end else if(cen) begin
        if( brlatch ) case(md[7:4])
            4'b1000: brok <= 1;  // bra
            4'b1001: brok <= !c; // bcc
            4'b1011: brok <=  c; // bcs
            4'b1101: brok <= !z; // bne
            4'b1111: brok <=  z; // beq
            4'b0101: brok <= !v; // bvc
            4'b0111: brok <=  v; // bvs
            4'b0001: brok <= !n; // bpl
            4'b0011: brok <=  n; // bmi
            default: brok <= 0;
        endcase
        if( brcy ) brok <= rslt_cc[0];
    end
end

endmodule