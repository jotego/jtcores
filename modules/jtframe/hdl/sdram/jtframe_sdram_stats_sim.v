/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 22-12-2020 */

`timescale 1ns/1ps

module jtframe_sdram_stats_sim #(
    parameter AW=22)(
    input               rst,
    input               clk,
    // SDRAM interface
    // SDRAM_A[12:11] and SDRAM_DQML/H are controlled in a way
    // that can be joined together thru an OR operation at a
    // higher level. This makes it possible to short the pins
    // of the SDRAM, as done in the MiSTer 128MB module
    input       [12:0]  sdram_a,        // SDRAM Address bus 13 Bits
    input       [ 1:0]  sdram_ba,       // SDRAM Bank Address
    input               sdram_nwe,      // SDRAM Write Enable
    input               sdram_ncas,     // SDRAM Column Address Strobe
    input               sdram_nras,     // SDRAM Row Address Strobe
    input               sdram_ncs       // SDRAM Chip Select
);

//                             /CS /RAS /CAS /WE
localparam CMD_LOAD_MODE   = 4'b0___0____0____0, // 0
           CMD_REFRESH     = 4'b0___0____0____1, // 1
           CMD_PRECHARGE   = 4'b0___0____1____0, // 2
           CMD_ACTIVE      = 4'b0___0____1____1, // 3
           CMD_WRITE       = 4'b0___1____0____0, // 4
           CMD_READ        = 4'b0___1____0____1, // 5
           CMD_STOP        = 4'b0___1____1____0, // 6 Burst terminate
           CMD_NOP         = 4'b0___1____1____1, // 7
           CMD_INHIBIT     = 4'b1___0____0____0; // 8

wire [3:0] cmd;

reg [12:0] last_row0, last_row1, last_row2, last_row3;

wire [31:0] count0, count1, count2, count3,
            samerow0, samerow1, samerow2, samerow3,
            longest0, longest1, longest2, longest3;

assign cmd = {sdram_ncs, sdram_nras, sdram_ncas, sdram_nwe };

jtframe_sdram_stats_bank #(0) u_bank0(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sdram_a    ( sdram_a   ),
    .sdram_ba   ( sdram_ba  ),
    .cmd        ( cmd       ),
    .count      ( count0    ),
    .longest    ( longest0  ),
    .samerow    ( samerow0  )
);

jtframe_sdram_stats_bank #(1) u_bank1(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sdram_a    ( sdram_a   ),
    .sdram_ba   ( sdram_ba  ),
    .cmd        ( cmd       ),
    .count      ( count1    ),
    .longest    ( longest1  ),
    .samerow    ( samerow1  )
);

jtframe_sdram_stats_bank #(2) u_bank2(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sdram_a    ( sdram_a   ),
    .sdram_ba   ( sdram_ba  ),
    .cmd        ( cmd       ),
    .count      ( count2    ),
    .longest    ( longest2  ),
    .samerow    ( samerow2  )
);

jtframe_sdram_stats_bank #(3) u_bank3(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sdram_a    ( sdram_a   ),
    .sdram_ba   ( sdram_ba  ),
    .cmd        ( cmd       ),
    .count      ( count3    ),
    .longest    ( longest3  ),
    .samerow    ( samerow3  )
);

integer last_cnt, last0, last1, last2, last3, new_cnt, delta;

initial begin
    last_cnt = 0;
    last0    = 0;
    last1    = 0;
    last2    = 0;
    last3    = 0;
    forever begin
        #16_666_667;
        new_cnt = count0 + count1 + count2 + count3;
        delta=new_cnt-last_cnt;
        $display("Data %5d kiB/s => BA STATS: %5d (%2d%%) - %5d (%2d%%) - %5d (%2d%%) - %5d (%2d%%)",
            delta*4*60/1024,
            (count0-last0)*4*60/1024, ((count0-last0)*100)/delta,
            (count1-last1)*4*60/1024, ((count1-last1)*100)/delta,
            (count2-last2)*4*60/1024, ((count2-last2)*100)/delta,
            (count3-last3)*4*60/1024, ((count3-last3)*100)/delta );
        $display("                 => Same row: %2d%% (%5d) - %2d%% (%5d) - %2d%% (%5d) - %2d%% (%5d)",
            (samerow0*100)/count0, longest0,
            (samerow1*100)/count1, longest1,
            (samerow2*100)/count2, longest2,
            (samerow3*100)/count3, longest3 );
        last_cnt = new_cnt;
        last0 = count0;
        last1 = count1;
        last2 = count2;
        last3 = count3;
    end
end

endmodule

module jtframe_sdram_stats_bank(
    input               rst,
    input               clk,
    input  [12:0]       sdram_a,
    input  [ 1:0]       sdram_ba,
    input  [ 3:0]       cmd,
    output     integer  count,
    output     integer  longest,
    output     integer  samerow
);

parameter BA=0;

integer cur;
reg [12:0] row;

wire act = cmd==4'd3 && sdram_ba==BA;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        count <= 0;
        longest <= 0;
        samerow <= 0;
        cur <= 0;
    end else begin
        if( act ) begin
            if( sdram_a == row ) begin
                cur <= cur + 1;
                samerow <= samerow + 1;
            end else begin
                cur <= 1;
                row <= sdram_a;
            end
            if( cur > longest ) longest <= cur;
            count <= count+1;
        end
    end
end

endmodule