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
    output reg           prom_we
);

localparam MAIN0_ADDR  = 22'h00000;
localparam MAIN1_ADDR  = 22'h20000;
localparam SND_ADDR    = 22'h40000;
localparam CHAR_ADDR   = 22'h48000;
// Scroll 1/2
localparam SCR1XY_ADDR = 22'h50000;
localparam SCR2XY_ADDR = 22'h70000;
localparam SCR1ZW_ADDR = 22'h78000;
localparam SCR2ZW_ADDR = 22'h98000;
localparam OBJZ_ADDR   = 22'hA0000;
localparam OBJX_ADDR   = 22'hC0000;
localparam MCU_ADDR    = 22'hE0000;
localparam PROM_ADDR   = 22'hE1000;
// ROM length E1100

// `ifdef SIMULATION
// wire region0_main  = ioctl_addr < SND_ADDR;
// wire region1_snd   = ioctl_addr < CHAR_ADDR;
// wire region2_char  = ioctl_addr < SCR1XY_ADDR;
// wire region3_scr1x = ioctl_addr < SCR1ZW_ADDR;
// wire region4_scr1z = ioctl_addr < SCR2XY_ADDR;
// wire region5_scry  = ioctl_addr < SCR2ZW_ADDR;
// wire region6_scrz2 = ioctl_addr < OBJZ_ADDR;
// wire region7_objzy = ioctl_addr < OBJX_ADDR;
// wire region8_objxw = ioctl_addr < MCU_ADDR;
// wire region8_objxw = ioctl_addr < PROM_ADDR;
// `endif

// offset the SDRAM programming address by 
wire [ 3:0] scr_msb = ioctl_addr[19:16]-5'b0101;
reg  [15:0] obj_offset=16'd0;

reg set_strobe, set_done;
reg prom_we0 = 1'd0;

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
        if( ioctl_addr[19:16] < SND_ADDR[19:16] ) begin // Main ROM, 16 bits per word
            prog_addr <= {1'b0, ioctl_addr[16:0]}; // A[17] ignored
                // because it sets the boundary
            prog_mask <= ioctl_addr[17]==1'b0 ? 2'b10 : 2'b01;            
        end
        else if(ioctl_addr[19:16] < SCR1XY_ADDR[19:16]) begin // Sound ROM, CHAR ROM
            prog_addr <= {1'b0, ioctl_addr[19:16]-6'd2, ioctl_addr[15:1]};
            prog_mask <= {ioctl_addr[0], ~ioctl_addr[0]};
        end
        else if(ioctl_addr[19:16] < OBJZ_ADDR[19:16] ) begin // Scroll    
            prog_mask <= scr_msb<5'b010_1 ? 2'b01 : 2'b10;
            prog_addr <= { scr_msb[3:0],ioctl_addr[14:0]} }; // original bit order
            scr_offset <= scr_offset+17'd1;
            obj_part   <= 1'b0;
        end
        else if(ioctl_addr < PROMS ) begin // Objects
            prog_mask <= obj_part ? 2'b10 : 2'b01;
            if( obj_offset == 16'hBFFF ) begin
                obj_offset <= 16'd0;
                obj_part   <= 1'b1;
            end else begin
                obj_offset <= obj_offset+16'd1;
            end
            prog_addr <= (OBJZ_ADDR>>1) + { 6'd0, {obj_offset[15:6], obj_offset[4:1], obj_offset[5], obj_offset[0] } };
        end
        else begin // PROMs
            prog_addr <= { {22-8{1'b0}}, ioctl_addr[7:0] };
            prog_we   <= 1'b0;
            prog_mask <= 2'b11;
            prom_we0  <= 1'd0;
            case(ioctl_addr[10:8])
                3'h0: prom_we0 <= 1'b1;
                default:;
            endcase
            set_strobe <= 1'b1;
        end
    end
    else begin
        prog_we  <= 1'b0;
        prom_we0 <= 1'd0;
    end
end

endmodule // jt1492_promprog