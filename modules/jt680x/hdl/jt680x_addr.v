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
    input      [ 3:0] dout_sel,
    // Bus
    input      [ 7:0] din,
    output reg [15:0] ea, addr,
    output reg [ 7:0] dout,
    output reg        vma, rw
);

`include "jt680x.vh"

reg  [15:0] tempind, tempea;

always begin
    case(bus_ctrl)
        FETCH_BC: begin
            address = pc;
            vma     = 1;
            rw      = 1;
        end
        READ_BC: begin
            address = ea;
            vma     = 1;
            rw      = 1;
        end
        WRITE_BC: begin
            address = ea;
            vma     = 1;
            rw      = 0;
        end
        PUSH_BC: begin
            address = sp;
            vma     = 1;
            rw      = 0;
        end
        PULL_BC: begin
            address = sp;
            vma     = 1;
            rw      = 1;
        end
        INT_HI_BC: begin
            address = { 12'hfff, iv, 1'b0};
            vma     = 1;
            rw      = 1;
        end
        INT_LO_BC: begin
            address = { 12'hf, iv, 1'b1};
            vma     = 1;
            rw      = 1;
        end
        default: begin
            address = 16'hffff;
            vma     = 0;
            rw      = 1;
        end
    endcase
end

always @(*) begin
    case (dout_sel)
        MD_HI_DOUT: dout = md[15:8];    // alu output
        MD_LO_DOUT: dout = md[ 7:0];
        ACCA_DOUT:  dout = acca;        // accumulator a
        ACCB_DOUT:  dout = accb;        // accumulator b
        IX_LO_DOUT: dout = xreg[ 7:0];  // index reg
        IX_HI_DOUT: dout = xreg[15:8];
        CC_DOUT:    dout = cc;
        PC_LO_DOUT: dout = pc[7:0];     // pc
        PC_HI_DOUT: dout = pc[15:8];
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
        ADD_IX_EA: tempind = { 8'd0, ea[7:0] };
        INC_EA:    tempind = 1;
        default:   tempind = 0;
    endcase

    case (ea_ctrl)
        RESET_EA:       tempea = 0;
        LOAD_ACCB_EA:   tempea = { 8'd0, accb[7:0] };
        ADD_IX_EA:      tempea = xreg;
        FETCH_FIRST_EA: tempea = { 8'd0, din };
        FETCH_NEXT_EA:  tempea = { ea[7:0], din };
        default:        tempea = ea;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ea <= 0;
    end else if( cen ) begin
        ea <= tempea + tempind;
    end
end

endmodule