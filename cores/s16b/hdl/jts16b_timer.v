/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 5-7-2021 */

// SEGA 315-5250 model, based on MAME driver

module jts16b_timer(
    input              rst,
    input              clk,

    input      [23:1]  A,
    input      [ 1:0]  dsn,
    input              rnw,
    input              cs,
    input      [15:0]  din,

    output reg         snd_irq, // seems unconnected in MAME

    output reg [15:0]  dout
);

reg  [15:0] mmr[0:7];
reg  [ 3:0] sel4;
reg  [ 7:0] snd_data;
reg         up_sel4;
wire write = cs && dsn==0 && !rnw;

wire signed [15:0] value, bound1, bound2, min, max;

assign value  = mmr[2];
assign bound1 = mmr[0];
assign bound2 = mmr[1];
assign min    = bound1 < bound2 ? bound1 : bound2;
assign max    = bound1 > bound2 ? bound1 : bound2;

function [15:0] write_reg( input [2:0] sel );
    write_reg = {
        !dsn[1] ? din[15:8] : mmr[sel][15:8],
        !dsn[0] ? din[ 7:0] : mmr[sel][ 7:0]
    };
endfunction

always @(posedge clk, posedge rst) begin
    if(rst) begin
        mmr[0] <= 0; mmr[1] <= 0; mmr[2] <= 0; mmr[3] <= 0;
        mmr[4] <= 0; mmr[5] <= 0; mmr[6] <= 0; mmr[7] <= 0;
        sel4 <= 0;
        up_sel4 <= 0;
    end else begin
        if( cs ) begin
            case( A[4:1] )
                0: dout <= mmr[0];
                1: dout <= mmr[1];
                2: dout <= mmr[2];
                3: dout <= mmr[3];
                4: dout <= mmr[4];
                5: dout <= mmr[1];  // 5 & 6 used to access 1 & 2 too
                6: dout <= mmr[2];
                7: dout <= mmr[7];
                default: dout <= 16'hffff;
            endcase
        end

        // comparison
        if( value<min ) begin
            mmr[7] <= min;
            mmr[3] <= 16'h8000;
        end else if( value>max ) begin
            mmr[7] <= max;
            mmr[3] <= 16'h4000;
        end else begin
            mmr[7] <= value;
            mmr[3] <= 16'h0000;
        end

        // write to registers
        if( write ) begin
            case(A[4:1])
                0: mmr[0] <= write_reg( 0 );
                1: mmr[1] <= write_reg( 1 );
                2: begin
                    mmr[2] <= write_reg( 2 );
                    mmr[4][sel4] <= mmr[3]==0;
                    up_sel4 <= 1;
                end
                4: begin
                    mmr[4] <= 0;
                    sel4   <= 0;
                end
                6: mmr[2] <= write_reg( 2 );
                4'hf: begin
                    snd_data <= din[7:0];
                    snd_irq  <= 1;
                end
            endcase
        end else begin
            up_sel4 <= 0;
            if( up_sel4 ) sel4 <= sel4+1'd1;
        end
    end
end

endmodule