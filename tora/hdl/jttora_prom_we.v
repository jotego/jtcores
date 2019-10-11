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

module jttora_prom_we(
    input                clk,
    input                downloading,
    input      [21:0]    ioctl_addr,
    input      [ 7:0]    ioctl_data,
    input                ioctl_wr,
    output reg [21:0]    prog_addr,
    output reg [ 7:0]    prog_data,
    output reg [ 1:0]    prog_mask, // active low
    output reg           prog_we,
    output reg           prom_we
);

localparam MAIN0_ADDR  = 22'h00000;
localparam MAIN1_ADDR  = 22'h20000;
localparam SND_ADDR    = 22'h40000;
localparam SND2_ADDR   = 22'h48000;
localparam CHAR_ADDR   = 22'h58000;
localparam MAP_ADDR    = 22'h60000;
// Scroll 1/2
localparam SCRZW_ADDR  = 22'h70000;
localparam SCRXY_ADDR  = 22'hF0000;
// even words
localparam OBJWZ_ADDR0 = 22'h170000;
localparam OBJXY_ADDR0 = 22'h190000;
// odd words
localparam OBJWZ_ADDR1 = 22'h1B0000;
localparam OBJXY_ADDR1 = 22'h1D0000;
// FPGA BRAM:
localparam PROM_ADDR   = 22'h1F0000;
// ROM length 1F0100


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

// offset the SDRAM programming address by 
wire [4:0] scr_msb = ioctl_addr[20:16]-5'h07;
wire [4:0] obj_msb = ioctl_addr[20:16]-5'h17;

reg       set_strobe=1'b0, set_done=1'b0;
reg       prom_we0 = 1'd0;

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
        if( ioctl_addr[20:16] < SND_ADDR[20:16] ) begin // Main ROM, 16 bits per word
            prog_addr <= {1'b0, ioctl_addr[16:0]}; // A[17] ignored
                // because it sets the boundary
            prog_mask <= ioctl_addr[17]==1'b1 ? 2'b10 : 2'b01;            
            `INFO_MAIN
        end
        else if(ioctl_addr[20:16] < SCRZW_ADDR[20:16]) begin
            // Sound ROM, CHAR ROM
            prog_addr <= {3'b0, ioctl_addr[20:16], ioctl_addr[15:1]};
            prog_mask <= {ioctl_addr[0], ~ioctl_addr[0]};
            `INFO_SND
        end
        else if(ioctl_addr[20:16] < OBJWZ_ADDR0[20:16] ) begin // Scroll
            // saved to 22'h10_0000  
            prog_mask <= scr_msb[3] ? 2'b01 : 2'b10;
            prog_addr <= { 3'b10,
                scr_msb[2:0],
                ioctl_addr[15:0] }; // original bit order
            `INFO_SCR
        end    
        else if(ioctl_addr[20:16] < PROM_ADDR[20:16] ) begin // Objects
            // saved to 22'h20_0000
            prog_mask <= obj_msb[1] ? 2'b10 : 2'b01;
            prog_addr <= { 4'b10_00,
                ~ioctl_addr[16],
                ioctl_addr[15:0], 
                obj_msb[2]}; // odd or even
            `INFO_OBJ
        end
        else begin // Priority PROM
            prog_addr <= ioctl_addr;
            prog_we   <= 1'b0;
            prog_mask <= 2'b11;
            prom_we0  <= 1'b1;
            set_strobe<= 1'b1;
            `INFO_PROM
        end
    end
    else begin
        prog_we  <= 1'b0;
        prom_we0 <= 1'd0;
    end
end

endmodule // jt1492_promprog