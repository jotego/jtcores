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
    Date: 1-5-2022 */

module jtvigil_pcm(
    input             rst,
                      clk,

    input             hi_cs, lo_cs, cnt_up,
    input     [ 7:0]  din,

    output reg        rom_cs,
    output reg [15:0] rom_addr,
    input      [ 7:0] rom_data,
    input             rom_ok,    

    output reg signed [7:0] snd
);

wire signed [7:0] pcm_signed;
reg cntup_l;

assign pcm_signed = 8'h80 - rom_data;

always @(posedge clk) begin
    if( rst ) begin
        rom_addr <= 16'd0;
        cntup_l  <= 0;
        snd      <= 0;
        rom_cs   <= 0;
    end else begin
        cntup_l    <= cnt_up;
        if( rom_cs && rom_ok ) begin
            snd    <= pcm_signed;
            rom_cs <= 0;
        end
        if( hi_cs ) rom_addr[15:8] <= din;
        if( lo_cs ) rom_addr[ 7:0] <= din;
        if( cnt_up && !cntup_l ) begin
            rom_addr <= rom_addr + 16'd1;
            rom_cs   <= 1;
        end
    end
end

endmodule