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

module jtbiocom_prom_we(
    input                clk,
    input                downloading,
    input      [21:0]    ioctl_addr,
    input      [ 7:0]    ioctl_data,
    input                ioctl_wr,
    output reg [21:0]    prog_addr,
    output reg [ 7:0]    prog_data,
    output reg [ 1:0]    prog_mask, // active low
    output reg           prog_we,
    output reg [ 1:0]    prom_we
);

localparam MAIN0_ADDR  = 22'h00000;
localparam MAIN1_ADDR  = 22'h20000;
localparam SND_ADDR    = 22'h40000;
localparam CHAR_ADDR   = 22'h48000;
// Scroll 1/2
localparam SCR1XY_ADDR = 22'h50000;
localparam SCR2XY_ADDR = 22'h70000;
localparam SCR1ZW_ADDR = 22'h80000;
localparam SCR2ZW_ADDR = 22'hA0000;
localparam OBJZ_ADDR   = 22'hB0000;
localparam OBJX_ADDR   = 22'hD0000;
localparam MCU_ADDR    = 22'hF0000;
localparam PROM_ADDR   = 22'hF1000;
// ROM length F1100

`ifdef SIMULATION
// simulation watchers
reg w_main, w_snd, w_char, w_scr, w_obj, w_mcu, w_prom;
`define CLR_ALL  {w_main, w_snd, w_char, w_scr, w_obj, w_mcu, w_prom} <= 7'd0;
`define SET_MAIN  w_main <= 1'b1;
`define SET_SND   w_snd  <= 1'b1;
`define SET_CHAR  w_char <= 1'b1;
`define SET_SCR   w_scr  <= 1'b1;
`define SET_OBJ   w_obj  <= 1'b1;
`define SET_MCU   w_mcu  <= 1'b1;
`define SET_PROM  w_prom <= 1'b1;
`else
// nothing for synthesis
`define CLR_ALL  
`define SET_MAIN 
`define SET_SND  
`define SET_CHAR 
`define SET_SCR  
`define SET_OBJ  
`define SET_MCU  
`define SET_PROM 
`endif

// offset the SDRAM programming address by 
wire [3:0] scr_msb = ioctl_addr[19:16]-4'd5;
wire [3:0] obj_msb = ioctl_addr[19:16]-4'hb;

reg set_strobe, set_done;
reg prom_we0 = 2'd0;

always @(posedge clk) begin
    prom_we <= 1'd0;
    if( set_strobe ) begin
        prom_we <= prom_we0;
        set_done <= 1'b1;
    end else if(set_done) begin
        set_done <= 1'b0;
    end
end

reg obj_part;

always @(posedge clk) begin
    if( set_done ) set_strobe <= 1'b0;
    if ( ioctl_wr ) begin
        prog_we   <= 1'b1;
        prog_data <= ioctl_data;
        `CLR_ALL
        if( ioctl_addr[19:16] < SND_ADDR[19:16] ) begin // Main ROM, 16 bits per word
            prog_addr <= {1'b0, ioctl_addr[16:0]}; // A[17] ignored
                // because it sets the boundary
            prog_mask <= ioctl_addr[17]==1'b0 ? 2'b10 : 2'b01;            
            `SET_MAIN
        end
        else if(ioctl_addr[19:16] < SCR1XY_ADDR[19:16]) begin // Sound ROM, CHAR ROM
            prog_addr <= {3'b0, ioctl_addr[19:16], ioctl_addr[15:1]};
            prog_mask <= {ioctl_addr[0], ~ioctl_addr[0]};
            `SET_SND
        end
        else if(ioctl_addr[19:16] < OBJZ_ADDR[19:16] ) begin // Scroll    
            prog_mask <= scr_msb[2:0] >= 3'd3 ? 2'b01 : 2'b10;
            prog_addr <= { 2'b0, scr_msb[3:0]+4'h5,ioctl_addr[15:0] }; // original bit order
            `SET_SCR
        end
        else if(ioctl_addr[19:16] < MCU_ADDR[19:16] ) begin // Objects
            prog_mask <= obj_msb[1] ? 2'b10 : 2'b01;
            prog_addr <= { 2'b0, obj_msb + 4'hB, 
                {ioctl_addr[15:6], ioctl_addr[4:1], ioctl_addr[5], ioctl_addr[0] } };
            `SET_OBJ
        end
        else if(ioctl_addr[19:12] < PROM_ADDR[19:12] ) begin // MCU
            prog_addr <= {6'hf, 1'b0, ioctl_addr[15:1]};
            prog_mask <= {ioctl_addr[0], ~ioctl_addr[0]};            
            prog_we   <= 1'b0;
            prog_mask <= 2'b11;
            prom_we0  <= 2'b1;
            `SET_MCU
        end
        else begin // PROMs
            prog_addr <= ioctl_addr;
            prog_we   <= 1'b0;
            prog_mask <= 2'b11;
            prom_we0  <= ioctl_addr[11:8] ? 2'b10 : 2'b0;
            set_strobe<= 1'b1;
            `SET_PROM
        end
    end
    else begin
        prog_we  <= 2'b0;
        prom_we0 <= 1'd0;
    end
end

endmodule // jt1492_promprog