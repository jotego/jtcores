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

module jtpcm568(
    input                rst,
    input                clk,
    input                cen,

    // CPU interface
    input                wr,
    input                cs,
    input         [12:0] addr, // A12 selects register (0) or memory (1)
    input         [ 7:0] din,
    output        [ 7:0] dout,

    // ADPCM RAM
    // Access by PCM logic (read only)
    output        [15:0] ram0_addr,
    input         [ 7:0] ram0_dout,
    // Access by CPU via PCM (RW)
    output        [15:0] ram1_addr,
    output        [ 7:0] ram1_din,
    input         [ 7:0] ram1_dout,
    output               ram1_we,

    output        [ 9:0] snd
);

reg  [ 3:0] bank;
reg  [ 7:0] chen_b;
wire [ 7:0] chwr;
reg  [ 2:0] chsel;
wire [63:0] chdout;
reg         mute_n;
wire        regwr;

assign ram1_addr = { bank, addr[11:0] };
assign ram1_we   = addr[12] & cs & wr;
assign ram1_din  = dout;
assign dout      = addr[12] ? ram1_dout : chdout[{chsel,3'd0}+:8];
assign regwr     = cs && wr && !addr[12];

// temporary
assign ram0_addr = 0;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mute_n <= 0;
        bank   <= 0;
        chen_b <= 0;
    end else begin
        if( regwr ) case(addr[3:0])
        7: begin
            mute_n <= din[7];
            if( din[6] )
                chsel <= din[2:0];
            else
                bank  <= din[3:0];
        end
        8: chen_b = din;
        endcase
    end
end

generate
    genvar k;
    for(k=0;k<8;k=k+1) begin
        assign chwr[k] = regwr && addr[2:0]==k;

        jtpcm568_ch u_ch(
            .rst        ( rst       ),
            .clk        ( clk       ),
            .cen        ( cen       ),
            .wr         ( chwr[k]   ),
            .addr       ( addr[2:0] ),
            .din        ( din       ),
            .dout       ( chdout[{k[2:0],3'd0}+:8] )
        );
    end
endgenerate

endmodule