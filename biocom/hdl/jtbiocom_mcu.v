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
    Date: 14-9-2019 */

`timescale 1ns/1ps

// Interface with sound CPU:
// The sound CPU can read and write to the MCU at a fixed
// address. The MCU only knows when data has been written to it
// The MCU responds by writting an answer. The MCU cannot
// know whether the sound CPU has read the value

// Interface with main CPU:
// The MCU takes control of the bus directly, including the bus decoder
// Because it doesn't drive AB[19:17], which will remain high, the MCU
// cannot access the PROM, OBJRAM, IO, scroll positions or char RAM
// It can drive both scrolls, palette and work RAM because it drives
// AB[16:14]. However, it doesn't have any bus arbitrion with the video
// components, so it wouldn't be able to access video components
// successfully. Thus, I am assuming that it only interacts with the
// work RAM

module jtbiocom_mcu(
    input           rst,
    input           clk,
    input           cen6,       //  6   MHz
    // Main CPU interface
    input           DMAONn,
    output  [ 7:0]  mcu_dout,
    input   [ 7:0]  mcu_din,
    output          mcu_wrn,   // always write to low bytes
    output  [16:1]  mcu_addr,
    output          mcu_brn,   // RQBSQn
    output          DMAn,
    // Sound CPU interface
    input   [ 7:0]  snd_dout,
    output  [ 7:0]  snd_din,
    input           snd_mcu_wr,
    // ROM programming
    input   [11:0]  prog_addr,
    input   [ 7:0]  prom_din,
    input           prom_we
);

wire [15:0] rom_addr, ext_addr;
wire [ 6:0] ram_addr;
wire [ 7:0] ram_data, ram_q, rom_data;
wire        ram_we;

wire [ 7:0] p3_o;
reg         int0, int1;

// interface with main CPU
assign mcu_addr[13:9] = ~5'b0;
assign { mcu_addr[16:14], mcu_addr[8:1] } = ext_addr[10:0];
assign mcu_brn  = int0;
assign DMAn     = p3_o[5];
reg    last_DMAONn;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        int0 <= 1'b1;
        last_DMAONn <= 1'b1;
    end else begin
        last_DMAONn <= DMAONn;
        if( !p3_o[0] ) // CLR
            int0 <= ~1'b0;
        else if(!p3_o[1]) // PR
            int0 <= ~1'b1;
        else if( DMAONn && !last_DMAONn )
            int0 <= ~1'b1;
    end
end


// interface with sound CPU
wire      int1_clrn = p3_o[4];

reg [7:0] snd_dout_latch;
reg       last_snd_mcu_wr;
wire      posedge_snd = snd_mcu_wr && !last_snd_mcu_wr;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd_dout_latch   <= 8'd0;
        int1            <= 1'b1;
        last_snd_mcu_wr <= 1'b0;
    end else begin
        last_snd_mcu_wr <= snd_mcu_wr;
        if( posedge_snd )
            snd_dout_latch <= snd_dout;
        // interrupt line
        if( !int1_clrn )
            int1 <= 1'b1;
        else if( posedge_snd ) int1 <= 1'b0;
    end
end

jtgng_prom #(.aw(12),.dw(8),.simfile("../../../rom/biocom/ts.2f")) u_prom(
    .clk        ( clk               ),
    .cen        ( 1'b1              ),
    .data       ( prom_din          ),
    .rd_addr    ( rom_addr[11:0]    ),
    .wr_addr    ( prog_addr         ),
    .we         ( prom_we           ),
    .q          ( rom_data          )
);

jtgng_ram #(.aw(7),.cen_rd(0)) u_ramu(
    .clk        ( clk               ),
    .cen        ( 1'b1              ),
    .addr       ( ram_addr          ),
    .data       ( ram_data          ),
    .we         ( ram_we            ),
    .q          ( ram_q             )
);

wire clk2 = clk&cen6; // cheap clock gating

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
    .datax_i    ( mcu_din ),
    .datax_o    ( mcu_dout  ),
    .adrx_o     ( ext_addr  ),
    .wrx_o      ( mcu_wrn  ),
    // interrupts
    .int0_i     ( int0      ),
    .int1_i     ( int1      ),
    // counters
    .all_t0_i   ( 1'b0      ),
    .all_t1_i   ( 1'b0      ),
    // serial interface
    .all_rxd_i  ( 1'b0      ),
    .all_rxd_o  (           ),
    // Ports
    .p0_i       (           ),
    .p0_o       (           ),

    .p1_i       ( snd_dout_latch   ),
    .p1_o       ( snd_din   ),

    .p2_i       (           ),
    .p2_o       (           ),

    .p3_i       (           ),
    .p3_o       ( p3_o      )
);

`ifdef SIMULATION
always @(negedge int0)
    $display ("MCU: int0 edge - main CPU");

always @(negedge int1)
    $display ("MCU: int1 edge - sound CPU");
`endif
endmodule