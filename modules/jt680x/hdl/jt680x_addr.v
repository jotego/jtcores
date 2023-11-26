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

module jt680x_addr(
    input             rst,
    input             clk,
    input             cen,
    // Registers
    input      [15:0] pc, sp,
    // Control
    input      [ 2:0] ea_ctrl, bus_ctrl, md_ctrl, iv,
    input      [ 3:0] dout_ctrl,
    // Bus
    input      [ 7:0] din,
    output reg [15:0] ea, addr,
    output reg [ 7:0] dout,
    output reg        vma, rw
);

`include "jt680x.vh"

reg  [15:0] nx_ea;

always begin
    case(bus_ctrl)
        READ_BUS:   address = ea;
        WRITE_BUS:  address = ea;
        PUSH_BUS:   address = sp;
        PULL_BUS:   address = sp;
        INT_HI_BUS: address = { 12'hfff, iv, 1'b0};
        INT_LO_BUS: address = { 12'hfff, iv, 1'b1};
        default:    address = pc;
    endcase
end

always @(*) begin
    case (dout_ctrl)
        MD_HI_DOUT: dout = md[15:8];    // alu output
        MD_LO_DOUT: dout = md[ 7:0];
        ACCA_DOUT:  dout = acca;        // accumulator a
        ACCB_DOUT:  dout = accb;        // accumulator b
        IX_LO_DOUT: dout = xreg[ 7:0];  // index reg
        IX_HI_DOUT: dout = xreg[15:8];
        CC_DOUT:    dout = cc;
        // PC_LO_DOUT: dout = pc[7:0];     // pc
        // PC_HI_DOUT: dout = pc[15:8];
        default:    dout = 8'd0;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
       md <= 0;
    end else if( cen ) begin
        case (md_ctrl)
            LOAD_MD:     md <= rslt[15:0];
            FETCH_LO_MD: md <= { 8'd0, din };
            FETCH_HI_MD: md <= { md[7:0], din };
            SHIFTL_MD:   md <= md << 1;
            default:;
        endcase
    end
end

always @(*) begin
    case (ea_ctrl)
        LOAD_ACCB_EA:   nx_ea = { 8'd0, accb[7:0] };
        ADD_IX_EA:      nx_ea = xreg;
        FETCH_FIRST_EA: nx_ea = { 8'd0, din };
        FETCH_NEXT_EA:  nx_ea = { ea[7:0], din };
        INC_EA:         nx_ea = ea+16'd1;
        default:        nx_ea = ea;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ea <= 0;
    end else if( cen ) begin
        ea <= nx_ea;
    end
end

endmodule