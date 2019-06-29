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
    input                clk_rom,
    input                clk_rgb,
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
// SCROLL Z     starts at 20000h
// Objects ZY   starts at 28000h
// SCROLL Y     starts at 34000h
// SCROLL Z     starts at 3C000h
// Objects XW   starts at 44000h
// PROMs        starts at 50000h
// length 5_0600h

localparam 
    SNDADDR  = 22'h0_C000, 
    CHARADDR = 22'h1_0000,
    SCRXADDR = 22'h1_4000,  // LSB: 01_0100_
    OBJZADDR = 22'h2_8000,
    SCRYADDR = 22'h3_4000,  // MSB: 11_0100_
    OBJXADDR = 22'h4_4000,
    PROMS    = 22'h5_0000,
    ROMEND   = 22'h5_0600;
wire [21:0] scr_offset = ioctl_addr - SCRXADDR;
wire scr_region = (ioctl_addr>=SCRXADDR&& ioctl_addr<OBJZADDR) ||
    (ioctl_addr>=SCRYADDR && ioctl_addr<OBJXADDR);

reg set_strobe, set_done;
reg [12:0] prom_we0;

always @(posedge clk_rgb) begin
    prom_we <= 'd0;
    if( set_strobe ) begin
        prom_we <= prom_we0;
        set_done <= 1'b1;
    end else if(set_done) begin
        set_done <= 1'b0;
    end
end

always @(posedge clk_rom) begin
    if( set_done ) set_strobe <= 1'b0;
    if ( ioctl_wr ) begin
        prog_we   <= 1'b1;
        prog_data <= ioctl_data;
        if(ioctl_addr < SCRXADDR) begin // Main ROM, CHAR ROM
            prog_addr <= {1'b0, ioctl_addr[21:1]};
            prog_mask <= {ioctl_addr[0], ~ioctl_addr[0]};
        end
        else if(ioctl_addr < PROMS) begin            
            prog_mask <= { scr_offset[16], ~scr_offset[16]};
            prog_addr <= SCRXADDR[21:1] + (
                scr_region ? {scr_offset[21:5], scr_offset[3:0], scr_offset[4] } // bit order swapped to increase cache hits
                    : scr_offset );
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
        prog_we <= 1'b0;
    end
end

endmodule // jt1492_promprog