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
    Date: 19-3-2023 */

module jtngp_snd(
    input                rstn,
    input                clk,
    input                cen3,

    input                snd_en,

    input         [11:1] main_addr,
    input         [15:0] main_dout,
    output        [15:0] main_din,
    input         [ 1:0] main_we,
    output               main_int5,
    input         [ 7:0] comm,      // where do we store these 8 bits?
    input                nmi,
    input                irq,
    output               irq_ack,

    input  signed [ 7:0] snd_dacl, snd_dacr,


    output               sample,
    output signed [15:0] snd_l, snd_r
);

wire [15:0] cpu_addr;
wire [ 1:0] ram_bwe;
reg  [ 7:0] cpu_din;
wire [ 7:0] ram_lsb, ram_msb, cpu_dout;
reg         ram_cs, psg_cs, latch_cs, intset_cs;
wire        wr_n, m1_n, mreq_n, iorq_n;

assign sample  = 0;
assign snd_l   = { snd_dacl, 8'd0 };
assign snd_r   = { snd_dacr, 8'd0 };
assign ram_bwe = {2{ram_cs&~wr_n}} & { cpu_addr[0], ~cpu_addr[0] };
assign irq_ack = !m1_n && !iorq_n;
assign main_int5 = intset_cs;

always @* begin
    ram_cs    = !mreq_n && cpu_addr[15:14]==0;
    psg_cs    = !mreq_n && cpu_addr[15:14]==1;
    latch_cs  = !mreq_n && cpu_addr[15:14]==2; // part of main's IO map
    intset_cs = !mreq_n && cpu_addr[15:14]==3;
end

always @(posedge clk) begin
    cpu_din <=  latch_cs ? comm :
                ram_cs   ? (cpu_addr[0] ? ram_msb : ram_lsb ) : 8'h00;
end

// jtframe_edge #(.QSET(0)) u_mainint(
//     .rst    ( ~rstn     ),
//     .clk    ( clk       ),
//     .edgeof ( intset_cs ),
//     .clr    ( ~iorq_n   ),
//     .q      ( main_int5 )
// );

jtframe_dual_ram #(.AW(11)) u_ramlow(
    // Port 0
    .clk0   ( clk             ),
    .data0  ( main_dout[7:0]  ),
    .addr0  ( main_addr       ),
    .we0    ( main_we[0]      ),
    .q0     ( main_din[7:0]   ),
    // Port 1
    .clk1   ( clk             ),
    .data1  ( cpu_dout        ),
    .addr1  ( cpu_addr[11:1]  ),
    .we1    ( ram_bwe[0]      ),
    .q1     ( ram_lsb         )
);

jtframe_dual_ram #(.AW(11)) u_ramhi(
    // Port 0
    .clk0   ( clk             ),
    .data0  ( main_dout[15:8] ),
    .addr0  ( main_addr       ),
    .we0    ( main_we[1]      ),
    .q0     ( main_din[15:8]  ),
    // Port 1
    .clk1   ( clk             ),
    .data1  ( cpu_dout        ),
    .addr1  ( cpu_addr[11:1]  ),
    .we1    ( ram_bwe[1]      ),
    .q1     ( ram_msb         )
);

`ifndef NOSOUND
jtframe_z80_romwait #(.CLR_INT(1)) u_cpu(
    .rst_n      ( rstn      ),
    .clk        ( clk       ),
    .cen        ( cen3      ),
    .cpu_cen    (           ),
    .int_n      ( ~irq      ),
    .nmi_n      ( ~nmi      ),
    .busrq_n    ( 1'b1      ),
    .m1_n       ( m1_n      ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       (           ),
    .wr_n       ( wr_n      ),
    .rfsh_n     (           ),
    .halt_n     (           ),
    .busak_n    (           ),
    .A          ( cpu_addr  ),
    .din        ( cpu_din   ),
    .dout       ( cpu_dout  ),
    // ROM access
    .rom_cs     ( 1'b0      ),
    .rom_ok     ( 1'b1      )
);
`else
    assign m1_n=1, mreq_n=1, iorq_n=1, wr_n=1,
           cpu_addr=0, cpu_dout=0;
`endif

endmodule