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
    // registers
    input      [ 5:0] cc,
    // Bus
    input      [ 7:0] din,
    input             nmi_n, irq_n,
    // Control
    output reg [15:0] pc,
    output reg [ 2:0] iv,
);

`include "jt680x.vh"

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

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        uaddr <= 0;
    end else if(cen) begin
        if(!halt) uaddr[3:0] <= uaddr[3:0] + 1'd1;
        if( ni  ) uaddr      <= { md[7:0], 4'd0 };
        case( jsr_ctrl )
            RET_JSR:                      uaddr<=uret;
            IMM_JSR:   begin uret<=uaddr; uaddr<=IMM_SEQA;   end
            IMM16_JSR: begin uret<=uaddr; uaddr<=IMM16_SEQA; end
            IMM_JSR:   begin uret<=uaddr; uaddr<=IMM_SEQA;   end
            // etc...
            default:;
        endcase
    end
end

jt680x_ucode ucode(
    .dec_en   (dec_en   ),
    .dir2     (dir2     ),
    .ext2     (ext2     ),
    .ix_en    (ix_en    ),
    .load_sp  (load_sp  ),
    .memdec_en(memdec_en),
    .acca_ctrl(acca_ctrl),
    .accb_ctrl(accb_ctrl),
    .bus_ctrl (bus_ctrl ),
    .cc_ctrl  (cc_ctrl  ),
    .dout_ctrl(dout_ctrl),
    .ea_ctrl  (ea_ctrl  ),
    .ix_ctrl  (ix_ctrl  ),
    .md_ctrl  (md_ctrl  ),
    .op0_ctrl (op0_ctrl ),
    .op1_ctrl (op1_ctrl ),
    .op_ctrl  (op_ctrl  ),
    .pc_ctrl  (pc_ctrl  ),
    .seqa     (seqa     )
);

endmodule