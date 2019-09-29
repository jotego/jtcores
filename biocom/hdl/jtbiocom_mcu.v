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
    input   [ 7:0]  main_din,
    output  [ 7:0]  main_dout,
    output          main_rdn,
    output          main_wrn,   // always write to low bytes
    output  [16:1]  main_addr,
    output          main_brn, // RQBSQn
    output          DMAn,
    // Sound CPU interface
    input   [ 7:0]  snd_din,
    output  [ 7:0]  snd_dout,
    input           snd_mcu_wr,
    // ROM programming
    input   [11:0]  prog_addr,
    input   [ 7:0]  prom_din,
    input           prom_we
);

wire [15:0] rom_addr, ext_addr;
wire [ 7:0] rom_data;
wire [ 7:0] mcu_dout, mcu_din;

wire [ 7:0] p2_o, p3_o;
reg         int0, int1;

// interface with main CPU
assign main_addr[13:9] = ~5'b0;
assign { main_addr[16:14], main_addr[8:1] } = ext_addr[10:0];
assign main_brn = int0;
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

reg [7:0] snd_din_latch;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd_din_latch <= 8'd0;
        int1 <= 1'b1;
    end else begin
        if( snd_mcu_wr )
            snd_din_latch <= snd_din;
        // interrupt line
        if( !int1_clrn )
            int1 <= 1'b1;
        else if( snd_mcu_wr ) int1 <= 1'b0;
    end
end

// Program PROM
jtgng_prom #(.aw(12),.dw(8),.simfile("../../../rom/biocom/ts.2f")) u_prom(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prom_din      ),
    .rd_addr( rom_addr[11:0]),
    .wr_addr( prog_addr     ),
    .we     ( prom_we       ),
    .q      ( rom_data      )
);

oc8051_top u_mcu(
    .wb_rst_i   ( rst           ),
    .wb_clk_i   ( clk           ),
    .cen        ( cen6          ),
    // instruction rom
    .wbi_adr_o  ( rom_addr      ), 
    .wbi_dat_i  ( rom_data      ), 
    .wbi_ack_i  ( 1'b1          ), 

    //interface to data ram
    .wbd_dat_i  ( main_dout     ), 
    .wbd_dat_o  ( main_din      ),
    .wbd_adr_o  ( ext_addr      ), 
    .wbd_we_o   ( main_low_we   ), 
    .wbd_ack_i  ( 1'b1          ),
    .wbd_stb_o  (               ), 
    .wbd_cyc_o  (               ), 

    // interrupt interface
    .int0_i     ( int0          ), 
    .int1_i     ( int1          ),

    // port interface
    .p0_i       (               ),
    .p0_o       (               ),
    .p1_i       ( snd_din_latch ),
    .p1_o       ( snd_dout      ),
    .p2_i       (               ),
    .p2_o       ( p2_o          ),
    .p3_i       (               ),
    .p3_o       ( p3_o          ),

    .ea_in      ( 1'b1          )
);

endmodule