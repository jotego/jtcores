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
    input              mcu_halt,
    output             mcu_irqmain,
    // PROM
    output     [13:0]  rom_addr,
    input      [ 7:0]  rom_data,
    output             rom_cs,
    input              rom_ok

);

wire        vma, halted, shared_cs, rnw,
            cpu_cen, nmi, nmi_clr;
wire [15:0] A;
wire [ 7:0] mcu_dout, p6_dout, sh2mcu_dout;
reg         waitn;

assign nmi_clr     = ~p6_dout[0];
assign mcu_irqmain =  p6_dout[1];
assign mcu_ban     = vma;
assign shared_cs   = vma && A[15:12]==8;
assign cpu_cen     = mcu_cen & (waitn | ~mcu_rstb);

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

// Clock enable

always @(posedge clk) begin : cpu_clockenable
    waitn <= rom_ok | ~rom_cs;
end

jt63701y #(.ROMW(14)) u_63701(
    .rst        ( ~mcu_rstb     ),
    .clk        ( clk           ),
    .cen        ( cpu_cen       ),

    // Bus
    .rnw        ( rnw           ),
    .x_cs       ( vma           ),
    .A          ( A             ),
    .xdin       ( sh2mcu_dout   ),
    .dout       ( mcu_dout      ),

    // interrupts
    .halt       ( mcu_halt      ),
    .halted     ( halted        ),
    .irq        ( 1'b0          ),
    .nmi        ( nmi           ),
    // ports
    .p1_din     ( 8'd0          ),
    .p2_din     ( 8'd0          ),
    .p3_din     ( 8'd0          ),
    .p4_din     ( 8'd0          ),
    .p5_din     ( 8'd0          ),
    .p6_din     ( 8'd0          ),

    .p1_dout    (               ),
    .p2_dout    (               ),
    .p3_dout    (               ),
    .p4_dout    (               ),
    .p5_dout    (               ),
    .p6_dout    ( p6_dout       ),
    // ROM
    .rom_cs     ( rom_cs        ),
    .rom_addr   ( rom_addr      ),
    .rom_data   ( rom_data      )
);

jtframe_dual_ram #(.AW(9)) u_shared(
    .clk0   ( clk         ),
    .clk1   ( clk         ),

    .data0  ( mcu_dout    ),
    .addr0  ( A[8:0]      ),
    .we0    ( ~rnw & shared_cs  ),
    .q0     ( sh2mcu_dout ),

    .data1  ( cpu_dout    ),
    .addr1  ( cpu_AB[8:0] ),
    .we1    ( ~cpu_wrn & com_cs & halted),
    .q1     ( shared_dout )
);

endmodule
