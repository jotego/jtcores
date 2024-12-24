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
    input                nmi,
    input                irq,
    output               irq_ack,

    input         [ 7:0] snd_latch,
    output reg    [ 7:0] main_latch,

    input  signed [ 7:0] snd_dacl, snd_dacr,

    output               sample,
    output signed [15:0] snd_l, snd_r,
    // Debug
    input         [ 7:0] debug_bus,
    output reg    [ 7:0] st_dout
);

wire [15:0] cpu_addr;
wire signed [11:0] snd_psg;
wire [ 1:0] ram_bwe;
reg  [ 7:0] cpu_din;
wire [ 7:0] ram_lsb, ram_msb, cpu_dout;
reg         ram_cs, psg_cs, latch_cs, intset_cs;
wire        wr_n, m1_n, mreq_n, iorq_n, rdy;

always @(posedge clk) begin
    case( debug_bus[1:0] )
        0: st_dout <= cpu_addr[ 7:0];
        1: st_dout <= cpu_addr[15:8];
        2: st_dout <= ram_lsb;
        3: st_dout <= ram_msb;
    endcase
end

assign sample  = 0;
assign ram_bwe = {2{ram_cs&~wr_n}} & { cpu_addr[0], ~cpu_addr[0] };
assign irq_ack = /*!m1_n && */ !iorq_n;
assign main_int5 = intset_cs;
assign snd_l = { 1'b0, snd_dacl, 7'd0 } + { snd_psg[11], snd_psg, 3'd0 };
assign snd_r = { 1'b0, snd_dacr, 7'd0 } + { snd_psg[11], snd_psg, 3'd0 };

always @* begin
    ram_cs    = !mreq_n && cpu_addr[15:14]==0;
    psg_cs    = !mreq_n && cpu_addr[15:14]==1;
    latch_cs  = !mreq_n && cpu_addr[15:14]==2; // part of main's IO map
    intset_cs = !mreq_n && cpu_addr[15:14]==3;
end

always @(posedge clk) begin
    cpu_din <=  latch_cs ? snd_latch :
                ram_cs   ? (cpu_addr[0] ? ram_msb : ram_lsb ) : 8'h00;
    if( !wr_n && latch_cs ) main_latch <= cpu_dout;
end

jtngp_psg u_psg(
    .rst    ( ~rstn         ),
    .clk    ( clk           ),
    .cen    ( cen3          ),

    .r_wn   ( wr_n          ),
    .cs     ( psg_cs        ),
    .a0     ( cpu_addr[0]   ),
    .din    ( cpu_dout      ),
    .ready  ( rdy           ),
    .snd    ( snd_psg       )
);

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
jtframe_z80 #(.CLR_INT(1)) u_cpu(
    .rst_n      ( rstn      ),
    .clk        ( clk       ),
    .cen        ( cen3      ),
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
    .wait_n     ( 1'b1      ),
    .A          ( cpu_addr  ),
    .din        ( cpu_din   ),
    .dout       ( cpu_dout  )
);
`else
    assign m1_n=1, mreq_n=1, iorq_n=1, wr_n=1,
           cpu_addr=0, cpu_dout=0;
`endif

endmodule