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
    Date: 19-3-2024 */

// Compatible with Ricoh RF5C68A

module jtpcm568_ch(
    input                rst,
    input                clk,
    input                cen,

    // CPU interface
    input                wr,
    input         [ 2:0] addr,
    input         [ 7:0] din,
    output reg    [ 7:0] dout,
    // status
    output reg    [ 7:0] env, pan,
    output reg    [15:0] fd,
    // sound address and actions
    output reg    [26:0] sa, // 16 (integer) + 11 (fractional)
    input                sel,
    input                loop,
    input                mute,
    input         [26:0] sanx
);

reg [15:0] ls;  // loop position
reg [ 7:0] staddr;

`ifdef SIMULATION
wire looped = loop & cen & sel;
`endif

// sound address
always @(posedge clk or posedge rst) begin
    if(rst) begin
        sa  <= 0;
    end else if( cen && sel) begin
        sa <= sanx;
        if( loop ) sa <= {ls,11'd0};
        if( mute ) sa <= {staddr,19'd0};
    end
end

// registers
always @(posedge clk or posedge rst) begin
    if(rst) begin
        fd     <= 0;
        ls     <= 0;
        pan    <= 0;
        env    <= 0;
        staddr <= 0;
    end else begin
        if( wr ) case(addr)
            0: env <= din;
            1: pan <= din;
            2: fd[ 7:0] <= din;
            3: fd[15:8] <= din;
            4: ls[ 7:0] <= din;
            5: ls[15:8] <= din;
            6: staddr   <= din;
            default:;
        endcase
        case(addr)
            0: dout <= env;
            1: dout <= pan;
            2: dout <= fd[7:0];
            3: dout <= fd[15:8];
            4: dout <= ls[7:0];
            5: dout <= ls[15:8];
            6: dout <= staddr;
        endcase
    end
end

endmodule