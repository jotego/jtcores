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
    Date: 17-11-2024 */

module jtflstory_main(
    input            rst,
    input            clk,
    input            cen,
    input            lvbl,       // video interrupt

    output    [15:0] bus_addr,
    output    [ 7:0] bus_din,
    output           bus_rnw,

    // Cabinet inputs
    input     [ 1:0] cab_1p,
    input     [ 1:0] coin,
    input     [ 5:0] joystick1,
    input     [ 5:0] joystick2,
    input     [23:0] dipsw,
    input            service,
    input            tilt,
    // ROM access
    output reg       rom_cs,
    output    [14:0] rom_addr,
    input     [ 7:0] rom_data,
    input            rom_ok,

    input     [ 7:0] debug_bus
);
`ifndef NOMAIN

wire [15:0] A, cpu_addr;
wire [ 7:0] bus_din;
reg  [ 7:0] cab;
wire        mreq_n, rfsh_n, busak_n, busrq_n, rd_n, wr_n, mcu_wrn;
reg         ram_cs, mmx_c, mmx_d, mmx_e, mmx_f;

assign bus_addr = A;
assign rom_addr = A[14:0];
assign cpu_addr = busak_n ? mcu_addr : cpu_addr;
assign bus_din  = busak_n ? mcu_dout : cpu_dout;
assign bus_we   = busak_n ? ~wr_n    : ~mcu_wrn;

always @* begin
    rom_cs  = 0;
    ram_cs  = 0;
    mmx_c   = 0;
    mmx_d   = 0;
    mmx_e   = 0;
    mmx_f   = 0;
    dip3_cs = 0;
    dip2_cs = 0;
    dip1_cs = 0;
    dip_cs  = 0;
    sh_cs   = 0;
    s2m_cs  = 0;
    cab_cs  = 0;
    if( !mreq_n && rfsh_n ) case(A[15:14])
        0,1,2: rom_cs = 1;
        3: case(A[13:12])
            0: mmx_c = 1;
            1: mmx_d = 1;
            2: mmx_e = 1;
            3: mmx_f = 1;
            default:;
        endcase
    endcase
end

always @(posedge clk) begin
    case(A[2:0])
        0: cab <= dipsw[ 7: 0];
        1: cab <= dipsw[15: 8];
        2: cab <= dipsw[23:16];
        3: cab <= {2'b11,coin,tilt,service,cab_1p};
        4: cab <= {2'b11,joystick1[3:0],joystick1[5:4]};
        6: cab <= {2'b11,joystick2[3:0],joystick2[5:4]};
    endcase
end

jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(1),.RECOVERY(1)) u_cpu(
    .rst_n      ( rst_n       ),
    .clk        ( clk         ),
    .cen        ( cen_eff     ),
    .cpu_cen    (             ),
    .int_n      ( lvbl        ), // int clear logic is internal
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( busrq_n     ),
    .busak_n    ( busak_n     ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .A          ( cpu_addr    ),
    .cpu_din    ( din         ),
    .cpu_dout   ( cpu_dout    ),
    .ram_dout   ( ram_dout    ),
    // ROM access
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);
`else
initial begin
end
`endif
endmodule