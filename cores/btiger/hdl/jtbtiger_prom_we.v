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
    Date: 29-6-2019 */

`timescale 1ns/1ps

module jtbtiger_prom_we(
    input                clk,
    input                downloading,
    input      [21:0]    ioctl_addr,
    input      [ 7:0]    ioctl_data,
    input                ioctl_wr,
    output reg [21:0]    prog_addr,
    output reg [ 7:0]    prog_data,
    output reg [ 1:0]    prog_mask, // active low
    output reg           prog_we,
    output reg [ 4:0]    prom_we
);

localparam MAIN_ADDR   = 22'h00000;
localparam SND_ADDR    = 22'h48000;
localparam CHAR_ADDR   = 22'h50000;
// Scroll
localparam SCRZW_ADDR  = 22'h60000;
localparam SCRXY_ADDR  = 22'h80000;
// objects
localparam OBJWZ_ADDR  = 22'hA0000;
localparam OBJXY_ADDR  = 22'hC0000;
// FPGA BRAM:
localparam MCU_ADDR    = 22'hE0000;
localparam PROM_ADDR   = 22'hE1000;
// ROM length E1400

`ifdef SIMULATION
// simulation watchers
reg w_main, w_snd, w_char, w_scr, w_obj, w_mcu, w_prom;
`define CLR_ALL   {w_main, w_snd, w_char, w_scr, w_obj, w_mcu, w_prom} <= 7'd0;
`define INFO_MAIN  w_main <= 1'b1;
`define INFO_SND   w_snd  <= 1'b1;
`define INFO_CHAR  w_char <= 1'b1;
`define INFO_SCR   w_scr  <= 1'b1;
`define INFO_OBJ   w_obj  <= 1'b1;
`define INFO_MCU   w_mcu  <= 1'b1;
`define INFO_PROM  w_prom <= 1'b1;
`else
// nothing for synthesis
`define CLR_ALL  
`define INFO_MAIN 
`define INFO_SND  
`define INFO_CHAR 
`define INFO_SCR  
`define INFO_OBJ  
`define INFO_MCU  
`define INFO_PROM 
`endif

reg set_strobe, set_done;
reg [4:0] prom_we0 = 5'd0;

always @(posedge clk) begin
    prom_we <= 5'd0;
    if( set_strobe ) begin
        prom_we <= prom_we0;
        set_done <= 1'b1;
    end else if(set_done) begin
        set_done <= 1'b0;
    end
end

reg obj_part;

wire incpu = ioctl_addr < CHAR_ADDR;

always @(posedge clk) begin
    if( set_done ) set_strobe <= 1'b0;
    if ( ioctl_wr ) begin
        prog_we   <= 1'b1;
        prog_data <= ioctl_data;
        `CLR_ALL
        if(ioctl_addr[21:16] < SCRZW_ADDR[21:16]) begin // Main/Sound ROM, CHAR ROM
            prog_addr <= {1'b0, ioctl_addr[21:1]};
            prog_mask <= {ioctl_addr[0], ~ioctl_addr[0]} ^ {2{incpu}};
            `INFO_MAIN
            `INFO_SND
            `INFO_CHAR
        end
        else if(ioctl_addr[21:16] < OBJWZ_ADDR[21:16] ) begin // Scroll    
            prog_mask <= ioctl_addr[19] ? 2'b01 : 2'b10;
            prog_addr <= { 5'd3, ioctl_addr[16:0] }; // original bit order
            `INFO_SCR
        end
        else if(ioctl_addr[21:16] < MCU_ADDR[21:16] ) begin // Objects
            prog_mask <= ioctl_addr[18] ? 2'b10 : 2'b01;
            prog_addr <= { 5'b00_101, {ioctl_addr[16:6], 
                ioctl_addr[4:1], ioctl_addr[5], ioctl_addr[0] } };
            `INFO_OBJ
        end
        else if(ioctl_addr[21:12] < PROM_ADDR[21:12] ) begin // MCU
            prog_addr <= ioctl_addr;
            prog_we   <= 1'b0;
            prog_mask <= 2'b11;
            prom_we0  <= 5'h10;
            set_strobe <= 1'b1;
            `INFO_MCU
        end
        else begin // PROMs
            prog_addr <= ioctl_addr;
            prog_we   <= 1'b0;
            prog_mask <= 2'b11;
            prom_we0  <= 5'd0;
            case(ioctl_addr[10:8])
                3'h0: prom_we0[0] <= 1'b1;
                3'h1: prom_we0[1] <= 1'b1;
                3'h2: prom_we0[2] <= 1'b1;
                3'h3: prom_we0[3] <= 1'b1;
                default:;
            endcase
            set_strobe <= 1'b1;
            `INFO_PROM
        end
    end
    else begin
        prog_we  <= 1'b0;
        prom_we0 <= 5'd0;
    end
end

endmodule