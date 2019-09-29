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

module jtbiocom_mcu(
    input           rst,
    input           clk,
    output          cen12,      // 12   MHz
    output          cen6,       //  6   MHz
    output          cen3,       //  3   MHz
    output          cen1p5,     //  1.5 MHz
    // Main CPU interface
    input           DMAONb,
    input   [ 7:0]  main_din,
    output  [ 7:0]  main_dout,
    output          main_rdn,
    output          main_wrn,   // always write to low bytes
    output  [16:1]  main_addr,
    output          main_rqbsqn, // RQBSQn
    output          DMAn,
    // Sound CPU interface

    // ROM programming
);

wire [15:0] rom_addr, ram_addr;
wire [ 7:0] rom_data;
wire [ 7:0] mcu_dout, mcu_din;

oc8051_top u_mcu(
    .wb_rst_i   ( rst       ),
    .wb_clk_i   ( clk       ),
    .cen        ( cen6      ),
    // instruction rom
    .wbi_adr_o  ( rom_addr  ), 
    .wbi_dat_i  ( rom_data  ), 
    .wbi_ack_i  ( 1'b1      ), 

    //interface to data ram
    .wbd_dat_i  ( mcu_din   ), 
    .wbd_dat_o  ( mcu_dout  ),
    .wbd_adr_o  ( ram_addr  ), 
    .wbd_we_o   ( ram_we    ), 
    .wbd_ack_i  ( 1'b1      ),
    .wbd_stb_o  (           ), 
    .wbd_cyc_o  (           ), 
    .wbd_err_i  ( 1'b0      ),

    // interrupt interface
    .int0_i     (           ), 
    .int1_i     (           ),


    // port interface
    .p0_i       (           ),
    .p0_o       (           ),
    .p1_i       (           ),
    .p1_o       (           ),
    .p2_i       (           ),
    .p2_o       (           ),
    .p3_i       (           ),
    .p3_o       (           ),
    // external access (active low)
    .ea_in      ( 1'b1      )
);

endmodule