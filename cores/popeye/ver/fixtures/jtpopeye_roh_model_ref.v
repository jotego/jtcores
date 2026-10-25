`include "fixtures.vh"
/*  This file is part of JTPOPEYE.
    JTPOPEYE program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTPOPEYE program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR AD PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTPOPEYE.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 12-3-2019 */

// Sheet 1 of 3, CPU

module jtpopeye_roh_model(
    input       VB_n,
    input       AI_n,
    input       BI_n,
    input       HBD_n,
    input       busak,
    output      ROHVS,
    output      ROHVCK,
    output      dma_cs,
    output      busrq_n,
    output [10:0] DM
);

wire MR_n;
wire busak_d;
wire DM10, H1l;

// LS74, 1L
jt7474 u_2D0(
    .d      ( ~BI_n ),
    .pr_b   ( 1'b1  ),
    .cl_b   ( 1'b1  ),
    .clk    ( ~AI_n ),
    .q      ( H1l   ),
    .q_b    (       )
);

jt7474 u_2D1(
    .d      ( busak     ),
    .pr_b   ( 1'b1      ),
    .cl_b   ( 1'b1      ),
    .clk    ( BI_n      ),
    .q      ( busak_d   ),
    .q_b    (           )
);

assign dma_cs = busak_d;

jt7474 u_1L(
    .d      ( 1'b1      ),
    .pr_b   ( 1'b1      ),
    .cl_b   ( ~DM10     ),
    .clk    ( ~VB_n     ),
    .q      (           ),
    .q_b    ( busrq_n   )
);

// LS74, 1C
wire ff_1c0;
wire ff_1c0_clr_n = ~(~busrq_n & ~busak_d);
wire ff_1c0_din   = ~(~busak_d & HBD_n);

jt7474 u_1C0(
    .d      ( ff_1c0_din   ),
    .pr_b   ( 1'b1         ),
    .cl_b   ( ff_1c0_clr_n ),
    .clk    ( H1l          ),
    .q      ( ff_1c0       ),
    .q_b    (              )
);

wire ff_1c1;
wire ff_1c1_din = ~( ~ff_1c0 & ff_1c0_din );

jt7474 u_1C1(
    .d      ( ff_1c1_din ),
    .pr_b   ( 1'b1       ),
    .cl_b   ( 1'b1       ),
    .clk    ( ~AI_n      ),
    .q      ( ff_1c1     ),
    .q_b    (            )
);

assign ROHVS  = ~ff_1c1 | ~ff_1c1_din;
assign ROHVCK = ~( ~ff_1c1 & ~BI_n );
assign MR_n   = ff_1c1_din;

wire [11:0] DMAcnt;
wire [1:0]  carry;
assign DM10 = DMAcnt[10];
assign DM = DMAcnt[10:0];

wire cnt_clk = AI_n;
wire cnt_en  = ~( H1l &  busak_d );

jt74161 u_1F(
    .VDD(1'b1), .VSS(1'b0),
    .cet    ( cnt_en      ),
    .cep    ( cnt_en      ),
    .ld_b   ( 1'b1        ),
    .clk    ( cnt_clk     ),
    .cl_b   ( MR_n        ),
    .d      ( 4'd0        ),
    .q      ( DMAcnt[3:0] ),
    .ca     ( carry[0]    )
 );

jt74161 u_2F(
    .VDD(1'b1), .VSS(1'b0),
    .cet    ( carry[0]    ),
    .cep    ( 1'b1        ),
    .ld_b   ( 1'b1        ),
    .clk    ( cnt_clk     ),
    .cl_b   ( MR_n        ),
    .d      ( 4'd0        ),
    .q      ( DMAcnt[7:4] ),
    .ca     ( carry[1]    )
 );

jt74161 u_2E(
    .VDD(1'b1), .VSS(1'b0),
    .cet    ( carry[1]    ),
    .cep    ( 1'b1        ),
    .ld_b   ( 1'b1        ),
    .clk    ( cnt_clk     ),
    .cl_b   ( MR_n        ),
    .d      ( 4'd0        ),
    .q      ( DMAcnt[11:8]),
    .ca     (             )
 );


endmodule
