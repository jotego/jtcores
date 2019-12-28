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
    Date: 20-1-2019 */

`timescale 1ns/1ps

module jt1942_prom_we(
    input                clk,
    input                downloading,
    input      [21:0]    ioctl_addr,
    input      [ 7:0]    ioctl_data,
    input                ioctl_wr,
    output reg [21:0]    prog_addr,
    output reg [ 7:0]    prog_data,
    output reg [ 1:0]    prog_mask,
    output reg           prog_we,
    output reg [9:0]     prom_we
);

// srb-03.m3  main    0x00000
// srb-04.m4  main    0x04000
// srb-05.m5  main    0x08000
// srb-06.m6  main    0x0c000
// srb-06.m6  main    0x0e000
// srb-07.m7  main    0x10000
// sr-01.c11  sound   0x14000
// sr-02.f2   char    0x18000

// sr-10.a3   scr     0x1A000
// sr-11.a4   scr     0x1C000
// sr-08.a1   scr     0x1E000
// sr-09.a2   scr     0x20000

// sr-12.a5   scr **  0x22000
// sr-13.a6   scr **  0x24000
// sr-12.a5   scr - filling
// sr-13.a6   scr - filling

// sr-14.l1   obj     0x2A000
// sr-16.n1   obj     0x2E000
// sr-15.l2   obj     0x32000
// sr-17.n2   obj     0x36000
// PROMs
// sb-1.k6            0x3A000
// sb-2.d1
// sb-3.d2
// sb-4.d6
// sb-5.e8
// sb-6.e9
// sb-7.e10
// sb-0.f1
// sb-8.k3
// sb-9.m11

parameter [21:0] MAINADDR  = 22'h0_0000;
parameter [21:0] SOUNDADDR = 22'h1_4000;
parameter [21:0] CHARADDR  = 22'h1_8000;

parameter [21:0]
           SCRADDR = 22'h1_A000, 
           SCRUPPER= 22'h2_2000,
           OBJADDR = 22'h2_A000,
           PROMADDR= 22'h3_A000;
reg [15:0] scr_offset;

reg set_strobe, set_done;
reg [9:0] prom_we0;

always @(posedge clk) begin
    if( set_strobe ) begin
        prom_we <= prom_we0;
        set_done <= 1'b1;
    end else if(set_done) begin
        prom_we <= 10'd0;
        set_done <= 1'b0;
    end
end

`ifdef SIMULATION
wire [3:0] region = { 
    ioctl_addr < PROMADDR, ioctl_addr < OBJADDR,
    ioctl_addr < SCRUPPER, ioctl_addr < SCRADDR };
`endif

wire incpu = ioctl_addr < CHARADDR;

always @(posedge clk) begin
    if( set_done ) set_strobe <= 1'b0;
    if ( ioctl_wr ) begin
        prog_we   <= 1'b1;
        prog_data <= ioctl_data;
        if(ioctl_addr < SCRADDR) begin // regular copy
            prog_addr <= {1'b0, ioctl_addr[21:1]};
            prog_mask <= ioctl_addr < SOUNDADDR ?
                ~{ioctl_addr[0], ~ioctl_addr[0]} : // main 
                ioctl_addr < CHARADDR ? 
                ~{ioctl_addr[0], ~ioctl_addr[0]} : // sound
                {ioctl_addr[0], ~ioctl_addr[0]}; // char
            scr_offset <= 16'd0;
        end
        else if(ioctl_addr < OBJADDR ) begin // scroll
            prog_mask <= scr_offset[14] ? 2'b10 : 2'b01;
            prog_addr <= (SCRADDR>>1) + 
                { scr_offset[15], scr_offset[13:0] }; // original bit order
            scr_offset <= scr_offset+16'd1;
        end        
        else if(ioctl_addr < PROMADDR ) begin // objects
            //**************************************************
            prog_mask  <= scr_offset[14] ? 2'b10 : 2'b01;
            prog_addr <= (OBJADDR>>1) + {scr_offset[15], // reordered to optimize cache hits
                scr_offset[13:6], scr_offset[4:1], scr_offset[5], scr_offset[0] };
            //**************************************************
            scr_offset <= scr_offset+16'd1;
        end
        else begin // PROMs
            prog_addr <= { 4'hF, ioctl_addr[17:0] };
            prog_mask <= 2'b11;
            case(ioctl_addr[11:8])
                4'd0: prom_we0 <= 10'h0_01;    // k6
                4'd1: prom_we0 <= 10'h0_02;    // d1
                4'd2: prom_we0 <= 10'h0_04;    // d2
                4'd3: prom_we0 <= 10'h0_08;    // d6
                4'd4: prom_we0 <= 10'h0_10;    // e8
                4'd5: prom_we0 <= 10'h0_20;    // e9
                4'd6: prom_we0 <= 10'h0_40;    // e10
                4'd7: prom_we0 <= 10'h0_80;    // f1
                4'd8: prom_we0 <= 10'h1_00;    // k3
                4'd9: prom_we0 <= 10'h2_00;    // m11
                default: prom_we0 <= 10'h0;    //
            endcase
            set_strobe <= 1'b1;
        end
    end
    else begin
        prog_we <= 1'b0;
    end
end

endmodule // jt1492_promprog