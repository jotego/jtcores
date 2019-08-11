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

module jtcommando_prom_we(
    input                clk,
    input                downloading,
    input      [21:0]    ioctl_addr,
    input      [ 7:0]    ioctl_data,
    input                ioctl_wr,
    output reg [21:0]    prog_addr,
    output reg [ 7:0]    prog_data,
    output reg [ 1:0]    prog_mask, // active low
    output reg           prog_we,
    output reg [ 5:0]    prom_we
);

// MAIN         starts at 00000h
// SOUND        starts at 0C000h
// CHAR         starts at 10000h
// SCROLL X     starts at 14000h
// SCROLL Z     starts at 1C000h
// Objects ZY   starts at 24000h
// SCROLL Y     starts at 30000h
// SCROLL Z     starts at 38000h
// Objects XW   starts at 40000h
// PROMs        starts at 4C000h
// ROM length 4C600h

localparam 
    SNDADDR  = 22'h0_C000, 
    CHARADDR = 22'h1_0000,

    SCRXADDR = 22'h1_4000,
    SCRZADDR = 22'h1_C000,
    SCRYADDR = 22'h2_4000,
    SCRZADDR2= 22'h2_C000,

    OBJZADDR = 22'h3_4000,
    OBJXADDR = 22'h4_0000,

    PROMS    = 22'h4_c000,
    ROMEND   = 22'h4_c600;

`ifdef SIMULATION
wire region0_main  = ioctl_addr < SNDADDR;
wire region1_snd   = ioctl_addr < CHARADDR;
wire region2_char  = ioctl_addr < SCRXADDR;
wire region3_scrx  = ioctl_addr < SCRZADDR;
wire region4_scrz  = ioctl_addr < SCRYADDR;
wire region5_scry  = ioctl_addr < SCRZADDR2;
wire region6_scrz2 = ioctl_addr < OBJZADDR;
wire region7_objzy = ioctl_addr < OBJXADDR;
wire region8_objxw = ioctl_addr < PROMS;
`endif

// offset the SDRAM programming address by 
reg [16:0] scr_offset=17'd0;
reg [15:0] obj_offset=16'd0;

reg set_strobe, set_done;
reg [5:0] prom_we0 = 6'd0;

always @(posedge clk) begin
    prom_we <= 6'd0;
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
        if(ioctl_addr < SCRXADDR) begin // Main ROM, CHAR ROM
            prog_addr <= {1'b0, ioctl_addr[21:1]};
            prog_mask <= {ioctl_addr[0], ~ioctl_addr[0]};
            scr_offset <= 17'd0;
        end
        else if(ioctl_addr < OBJZADDR ) begin // Scroll    
            prog_mask <= scr_offset[16] ? 2'b01 : 2'b10;
            prog_addr <= SCRXADDR[21:1] +
                // { 6'd0, scr_offset[15:5], scr_offset[3:0], scr_offset[4] }; // bit order swapped to increase cache hits
                { 6'd0, scr_offset[15:0] }; // original bit order
            scr_offset <= scr_offset+17'd1;
            obj_offset <= 16'd0;
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
            prog_addr <= (OBJZADDR>>1) + { 6'd0, {obj_offset[15:6], obj_offset[4:1], obj_offset[5], obj_offset[0] } };
        end
        else begin // PROMs
            prog_addr <= { {22-8{1'b0}}, ioctl_addr[7:0] };
            prog_we   <= 1'b0;
            prog_mask <= 2'b11;
            prom_we0 <= 6'd0;
            case(ioctl_addr[10:8])
                3'h0: prom_we0[0] <= 1'b1;
                3'h1: prom_we0[1] <= 1'b1;
                3'h2: prom_we0[2] <= 1'b1;
                3'h3: prom_we0[3] <= 1'b1;
                3'h4: prom_we0[4] <= 1'b1;
                3'h5: prom_we0[5] <= 1'b1;
                default:;
            endcase
            set_strobe <= 1'b1;
        end
    end
    else begin
        prog_we  <= 1'b0;
        prom_we0 <= 6'd0;
    end
end

endmodule // jt1492_promprog