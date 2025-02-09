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

    output    [15:0] bus_addr,
    output reg       bus_cs,
    output           bus_wr_n, bus_rd_n,
    output    [ 7:0] bus_din,
    input     [ 7:0] bus_dout,

    input            bus_wait,
    // ROM access
    output reg       rom_cs,
    input     [ 7:0] rom_data,
    input            rom_ok
);

wire [15:0] A;
wire [ 7:0] cpu_dout;
reg  [ 7:0] din;
reg         rst_n;
wire        mreq_n, rfsh_n, rd_n, wr_n, int_n;
wire        bus_cen;

assign A        = bus_addr;
assign int_n    = ~dip_pause | lvbl;

assign bus_cen  = cen & ~bus_wait;
assign bus_wr_n = wr_n;
assign bus_rd_n = rd_n;
assign bus_din  = cpu_dout;

always @* begin
    rom_cs      = 0;
    bus_cs      = 0;

    if( !mreq_n && rfsh_n ) case(A[15:14])
        0,1,2: rom_cs = 1;
            3: bus_cs = 1;
    endcase
end

always @* begin
    din = rom_cs ? rom_data : bus_dout;
end

always @(posedge clk) begin
    rst_n <= ~rst & enable;
end

jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(1),.RECOVERY(1)) u_cpu(
    .rst_n      ( rst_n       ),
    .clk        ( clk         ),
    .cen        ( bus_cen     ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ), // int clear logic is internal
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .busak_n    (             ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     (             ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .A          ( bus_addr    ),
    .cpu_din    ( din         ),
    .cpu_dout   ( cpu_dout    ),
    .ram_dout   (             ),
    // ROM access
    .ram_cs     ( 1'b0        ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);

endmodule