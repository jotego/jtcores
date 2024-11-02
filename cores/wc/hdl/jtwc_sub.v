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
    Date: 28-10-2024 */

module jtwc_sub(
    input            rst_n,
    input            clk,
    input            cen,
    input            vint,       // video interrupt (LVBL)
    input            ws,
    // shared memory
    output reg       mmx_c8,
    output reg       mmx_d0,
    output reg       mmx_d8,
    output reg       mmx_e0,
    output reg       mmx_e8,
    output    [ 7:0] cpu_dout,
    output           wr_n,
    input     [ 7:0] sh_dout,
    // ROM access
    output reg       rom_cs,
    output    [13:0] rom_addr,
    input     [ 7:0] rom_data,
    input            rom_ok
);

wire [15:0] A;
wire [ 7:0] ram_dout;
reg  [ 7:0] cpu_din;
reg         ram_cs, latch_cs, sh_cs;
wire        rd_n, iorq_n, rfsh_n, mreq_n, int_n, cen_eff;

assign rom_addr = A[13:0];
assign cen_eff  = ~ws & cen;
assign rfsh_n   = 0;

always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    mmx_c8   = 0;
    mmx_d0   = 0;
    mmx_d8   = 0;
    mmx_e0   = 0;
    mmx_e8   = 0;
    sh_cs    = 0;
    if( !mreq_n && !rfsh_n ) casez(A[15:14])
        0,1: rom_cs   = 1;
        3: case(A[13:11])
            0: ram_cs = 1;
            1: mmx_c8 = 1;
            2: mmx_d0 = 1;
            3: mmx_d8 = 1;
            4: mmx_e0 = 1;
            5: mmx_e8 = 1;
            default:;
        endcase
        default:;
    endcase
end

always @* begin
    cpu_din = rom_cs ? rom_data :
              ram_cs ? ram_dout : sh_dout;
end

jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(1)) u_cpu(
    .rst_n      ( rst_n       ),
    .clk        ( clk         ),
    .cen        ( cen_eff     ),
    .cpu_cen    (             ),
    .int_n      ( ~vint       ), // int clear logic is internal
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( 1'b1        ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     (             ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( cpu_din     ),
    .cpu_dout   ( cpu_dout    ),
    .ram_dout   ( ram_dout    ),
    // ROM access
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);

endmodule