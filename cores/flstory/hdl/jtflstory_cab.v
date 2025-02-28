/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 23-2-2025 */

module jtflstory_cab(
    input            clk,
                     cabcfg, iocfg,
    input      [2:0] addr,
    // status bits
    input            mcu_ibf, mcu_obf,
                     snd_ibf, snd_obf,
    // Cabinet inputs
    input     [ 1:0] cab_1p,
    input     [ 1:0] coin,
    input     [ 9:0] joystick1,
    input     [ 9:0] joystick2,    
    input     [23:0] dipsw,
    input            service,
    input            dip_pause, tilt,

    output reg [7:0] cab,
    input      [7:0] debug_bus
);
    localparam [1:0] LOW_FOR_FLSTORY=2'd0, HI_FOR_NYCAPTOR=2'b11;
    localparam [3:0] NOEXTRA=4'b1111;

    wire [ 7:0] mcu_st, snd_st;
    wire [ 3:0] extra1p, extra2p;
    reg  [ 1:0] unused_IO;

    assign mcu_st  = {2'b00,extra1p, mcu_obf, ~mcu_ibf};
    assign snd_st  = {6'h0,snd_obf, snd_ibf};
    assign extra1p = cabcfg ? joystick1[9:6] : NOEXTRA;
    assign extra2p = cabcfg ? joystick2[9:6] : NOEXTRA;

    function [7:0] arrange(input [9:0]joy); begin
        arrange = {2'b11,joy[3:0],joy[5:4]};
    end endfunction

    always @(posedge clk) begin
        unused_IO <= iocfg ? HI_FOR_NYCAPTOR : LOW_FOR_FLSTORY;

        case(addr[2:0])
            0: cab <= dipsw[ 7: 0];
            1: cab <= dipsw[15: 8];
            2: cab <= dipsw[23:16];
            3: cab <= {unused_IO,coin,tilt,service,cab_1p};
            4: cab <= arrange(joystick1);
            5: cab <= mcu_st;
            6: cab <= iocfg ? snd_st : arrange(joystick2);
            7: cab <= iocfg ? mcu_st : {2'b11,extra2p,2'b11};
        endcase
    end
endmodule