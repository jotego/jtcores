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

module jt680x_ctrl(
    input             rst,
    input             clk,
    input             cen,
    // Bus
    input      [ 7:0] din,
    input             nmi_n, irq_n,
    // Control
    output reg [15:0] pc,
    output reg [ 2:0] iv,
);

`include "jt680x.vh"

reg  [15:0] tempof, temppc;
reg  [ 2:0] pc_ctrl;
reg  [ 7:0] op_code;
wire        fetch;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        iv <= 7;
    end else if(cen) begin
        case (iv_ctrl)
            NMI_IV: iv <= 6;
            SWI_IV: iv <= 5;
            IRQ_IV: iv <= 4;
            ICF_IV: iv <= 3;
            OCF_IV: iv <= 2;
            TOF_IV: iv <= 1;
            SCI_IV: iv <= 0;
            default:;
        endcase
    end
end

always @(*) begin
  case (pc_ctrl)
    ADD_EA_PC: tempof = { {8{ea[7]}}, ea[7:0] };
    INC_PC:    tempof = 1;
    default:   tempof = 0;
  endcase

  case (pc_ctrl)
      LOAD_EA_PC: temppc = ea;
      PULL_LO_PC: temppc[15:8] = { pc[15:8], data_in };
      PULL_HI_PC: temppc[15:8] = { data_in, pc[7:0] };
      default:    temppc = pc;
  endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pc      <= 16'hfffe;
        op_code <= 1;
    end else begin if( cen ) begin
        pc <= temppc + tempof;
        if( op_ctrl ) op_code <= din;
    end
end

endmodule