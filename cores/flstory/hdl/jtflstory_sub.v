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
    Date: 9-2-2025 */

module jtflstory_sub(
    input            rst, enable,
                     clk,
                     cen,

    input            lvbl,       // video interrupt
                     nmi_n,
                     dip_pause,

    output    [15:0] addr,
    output reg       bus_cs,
    output           wr_n, rd_n,
    output    [ 7:0] dout,
    input     [ 7:0] bus_din,
    input            busrq_n,
                     bus_wait,
                     bus_rstn,
    // ROM access
    output reg       rom_cs,
    input     [ 7:0] rom_data,
    input            rom_ok,

    output reg       user1_cs,
    input     [ 7:0] user1_data,
    input            user1_ok
);

wire [15:0] A;
reg  [ 7:0] din;
reg         rst_n;
wire        mreq_n, iorq_n, m1_n, rfsh_n, int_n, busak_n,
            bus_cen, sdram_cs, sdram_ok;

assign A        = addr;
assign int_n    = ~dip_pause | lvbl;
assign sdram_cs = rom_cs | user1_cs,
       sdram_ok = rom_ok | user1_ok;

assign bus_cen  = cen & ~bus_wait;

always @* begin
    rom_cs   = 0;
    bus_cs   = 0;
    user1_cs = !iorq_n && m1_n;

    if( !mreq_n && rfsh_n ) case(A[15:14])
        0,1,2: rom_cs = 1;
            3: bus_cs = 1;
    endcase
end

always @* begin
    din = rom_cs   ? rom_data   :
          user1_cs ? user1_data :
                     bus_din;
end

always @(posedge clk) begin
    rst_n <= ~rst & enable & bus_rstn;
end

jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(1),.RECOVERY(1)) u_cpu(
    .rst_n      ( rst_n       ),
    .clk        ( clk         ),
    .cen        ( bus_cen     ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ), // int clear logic is internal
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( busrq_n     ),
    .busak_n    ( busak_n     ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .A          ( addr        ),
    .cpu_din    ( din         ),
    .cpu_dout   ( dout        ),
    .ram_dout   (             ),
    // ROM access
    .ram_cs     ( 1'b0        ),
    .rom_cs     ( sdram_cs    ),
    .rom_ok     ( sdram_ok    )
);

endmodule