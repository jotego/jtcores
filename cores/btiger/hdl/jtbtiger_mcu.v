/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 19-11-2019 */

`timescale 1ns/1ps

// based on 1943 schematics

module jtbtiger_mcu(
    input                rst,
    input                clk,
    input                cen6,       //  6   MHz
    // Main CPU interface
    output       [ 7:0]  mcu_dout,
    input        [ 7:0]  mcu_din,
    input                mcu_wr,
    // ROM programming
    input        [11:0]  prog_addr,
    input        [ 7:0]  prom_din,
    input                prom_we
);

wire [15:0] rom_addr;
wire [ 6:0] ram_addr;
wire [ 7:0] ram_data;
wire        ram_we;
wire [ 7:0] ram_q, rom_data;

wire [ 7:0] p1_o, p2_o, p3_o;


jtframe_prom #(.aw(12),.dw(8),
    .simfile("../../../rom/btiger/bd.6k")
) u_prom(
    .clk        ( clk               ),
    .cen        ( cen6             ),
    .data       ( prom_din          ),
    .rd_addr    ( rom_addr[11:0]    ),
    .wr_addr    ( prog_addr         ),
    .we         ( prom_we           ),
    .q          ( rom_data          )
);

jtframe_ram #(.aw(7),.cen_rd(1)) u_ramu(
    .clk        ( clk               ),
    .cen        ( cen6             ),
    .addr       ( ram_addr          ),
    .data       ( ram_data          ),
    .we         ( ram_we            ),
    .q          ( ram_q             )
);

wire clk2 = clk&cen6; // cheap clock gating

reg  [ 7:0] mcu_din0;

always @(posedge clk) if(cen6) begin
    mcu_din0 <= mcu_din;
end

reg mcu_int1;
reg last_mcu_wr;

// Port 3. All bits active low
// 4 output enable of from-CPU latch
// 5 clock pin of to-CPU latch
// 1 clear interrupt
// only bit 1 is needed in FPGA implementation
// Note that MAME clears the interrupt in a different way
// as it does it when the main CPU reads from the MCU

always @(posedge clk) begin
    last_mcu_wr <= mcu_wr;
    if( mcu_wr && !last_mcu_wr ) mcu_int1 <= 1'b0;
    if( !p3_o[1] ) mcu_int1 <= 1'b1;
end

mc8051_core u_mcu(
    .clk        ( clk2      ),
    .reset      ( rst       ),
    // code ROM
    .rom_data_i ( rom_data  ),
    .rom_adr_o  ( rom_addr  ),
    // internal RAM
    .ram_data_i ( ram_q     ),
    .ram_data_o ( ram_data  ),
    .ram_adr_o  ( ram_addr  ),
    .ram_wr_o   ( ram_we    ),
    .ram_en_o   (           ),
    // external memory: connected to main CPU
    .datax_i    (           ),
    .datax_o    (           ),
    .adrx_o     (           ),
    .wrx_o      (           ),
    // interrupts
    .int0_i     ( 1'b1      ),
    .int1_i     ( mcu_int1  ),
    // counters
    .all_t0_i   ( 1'b0      ),
    .all_t1_i   ( 1'b0      ),
    // serial interface
    .all_rxd_i  ( 1'b0      ),
    .all_rxd_o  (           ),
    // Ports
    .p0_i       ( mcu_din0  ),
    .p0_o       ( mcu_dout  ),

    .p1_i       (           ),
    .p1_o       ( p1_o      ),

    .p2_i       (           ),
    .p2_o       ( p2_o      ),

    .p3_i       (           ),
    .p3_o       ( p3_o      )
);

endmodule