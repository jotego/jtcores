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
    Date: 2-12-2019 */

// Port 4 configured as output --> use as address bus
// Port 6 configured as output

module jtdd_mcu(
    input              clk,
    input              mcu_rstb,
    input              mcu_cen,
    // CPU bus
    input      [ 8:0]  cpu_AB,
    input              cpu_wrn,
    input      [ 7:0]  cpu_dout,
    output     [ 7:0]  shared_dout,
    // CPU Interface
    input              com_cs,
    output             mcu_ban,
    input              mcu_nmi_set,
    input              mcu_haltn,
    output             mcu_irqmain,
    // PROM
    output     [13:0]  rom_addr,
    input      [ 7:0]  rom_data,
    output             rom_cs

);

wire        ba, shared_cs, wrn,
            nmi, nmi_clr;
wire [15:0] A;
wire [ 7:0] mcu_dout, p6_dout, sh2mcu_dout;
wire [ 4:0] p7_dout;

assign nmi_clr     = ~p6_dout[0];
assign mcu_irqmain =  p6_dout[1];
assign mcu_ban     = ~ba;
assign shared_cs   = A[15:12]==8;
assign wrn         = p7_dout[1];
assign ba          = p7_dout[4];

jtframe_ff u_nmi(
    .clk     (   clk          ),
    .rst     (   ~mcu_rstb    ),
    .cen     (   1'b1         ),
    .sigedge (   mcu_nmi_set  ),
    .din     (   1'b1         ),
    .clr     (   nmi_clr      ),
    .set     (   1'b0         ),
    .q       (   nmi          ),
    .qn      (                )
);

jt63701y #(.ROMW(14),.MODE(2'd2)) u_63701(
    .rst        ( ~mcu_rstb     ),
    .clk        ( clk           ),
    .cen        ( mcu_cen       ),
    // interrupts
    .nmi        ( nmi           ),
    // ports
    .p1_din     ( 8'd0          ),
    .p2_din     ( 8'd0          ),
    .p3_din     ( sh2mcu_dout   ),
    .p4_din     ( 8'd0          ),
    .p5_din     ({4'd0, mcu_haltn,3'd0}),
    .p6_din     ( 8'd0          ),

    .p1_dout    ( A[ 7:0]       ),
    .p2_dout    (               ),
    .p3_dout    ( mcu_dout      ),
    .p4_dout    ( A[15:8]       ),
    .p5_dout    (               ),
    .p6_dout    ( p6_dout       ),
    .p7_dout    ( p7_dout       ),
    // ROM
    .rom_cs     ( rom_cs        ),
    .rom_addr   ( rom_addr      ),
    .rom_data   ( rom_data      )
);

jtframe_dual_ram #(.AW(9)) u_shared(
    .clk0   ( clk         ),
    .clk1   ( clk         ),

    .addr0  ( A[8:0]      ),
    .data0  ( mcu_dout    ),
    .we0    ( ~wrn & shared_cs  ),
    .q0     ( sh2mcu_dout ),

    .data1  ( cpu_dout    ),
    .addr1  ( cpu_AB[8:0] ),
    .we1    ( ~cpu_wrn & com_cs & ba),
    .q1     ( shared_dout )
);

endmodule
