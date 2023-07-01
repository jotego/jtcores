/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 4-1-2020

*/

module jtframe_i8742(
    input        rst,
    input        clk,
    input        cen,

    //
    input        a0,
    input        cs_n,
    input        cpu_rdn,
    input        cpu_wrn,
    input  [7:0] din,
    output [7:0] dout,

    // Ports
    input  [7:0] p1_din,
    input  [7:0] p2_din,
    output [7:0] p1_dout,
    output [7:0] p2_dout,

    // Test pins (used in the assembler TEST instruction)
    input        t0_din,
    input        t1_din,

    input [10:0] prog_addr,
    input  [7:0] prog_data,
    input        prom_we,

    // Debug
    input  [7:0] st_addr,
    output reg [7:0] st_dout
);

parameter SIMFILE="8742.bin";

wire        cen_div3;
wire [ 7:0] ram_addr, ram_dout, ram_din, rom_data;
wire [10:0] rom_addr;
wire        ram_we;

always @(posedge clk) begin
    case( st_addr[3:0] )
        0: st_dout <= p1_din;
        1: st_dout <= p2_din;
        2: st_dout <= p1_dout;
        3: st_dout <= p2_dout;
        4: st_dout <= rom_addr[7:0];
        5: st_dout <= { 5'd0, rom_addr[10:8] };
        6: st_dout <= rom_data;
        7: st_dout <= { 6'd0, t1_din, t0_din };
        default: st_dout <= 0;
    endcase
end

upi41_core u_t48(
    // T48 interface
    .reset_i        ( ~rst      ),
    .xtal_i         ( clk       ),
    .xtal_en_i      ( cen       ),

    .a0_i           ( a0        ),
    .cs_n_i         ( cs_n      ),
    .rd_n_i         ( cpu_rdn   ),
    .wr_n_i         ( cpu_wrn   ),
    // Test pins
    .t0_i           ( t0_din    ),
    .t1_i           ( t1_din    ),

    .sync_o         (           ),
    .prog_n_o       (           ),
    // Data bus
    .db_i           ( din       ),
    .db_o           ( dout      ),
    .db_dir_o       (           ),
    // Port 1
    .p1_i           ( p1_din & p1_dout ),
    .p1_o           ( p1_dout   ),
    .p1_low_imp_o   (           ),
    // Port 2
    .p2_i           ( p2_din & p2_dout ),
    .p2_o           ( p2_dout   ),
    .p2l_low_imp_o  (           ),
    .p2h_low_imp_o  (           ),
    // Core interface
    .clk_i          ( clk       ),
    .en_clk_i       ( cen_div3  ),
    .xtal3_o        ( cen_div3  ),
    .dmem_addr_o    ( ram_addr  ),
    .dmem_we_o      ( ram_we    ),
    .dmem_data_i    ( ram_dout  ),
    .dmem_data_o    ( ram_din   ),
    .pmem_addr_o    ( rom_addr  ),
    .pmem_data_i    ( rom_data  )
);

jtframe_prom #(
    .AW(11),
    .SIMFILE(SIMFILE)
) u_prom (
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( prog_data ),
    .rd_addr( rom_addr[10:0] ),
    .wr_addr( prog_addr ),
    .we     ( prom_we   ),
    .q      ( rom_data  )
);

jtframe_ram #(.AW(8)) u_ram(
    .clk    ( clk       ),
    .cen    ( 1'b1      ), // this may create problems
    .data   ( ram_din   ),
    .addr   ( ram_addr  ),
    .we     ( ram_we    ),
    .q      ( ram_dout  )
);

endmodule