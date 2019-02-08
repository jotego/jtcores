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
    Date: 8-2-2019 */

module jtgng_zxuno_prog(
    input         rst,
    input         clk,
    // Flash
    // SRAM
    output reg    sram_we_n,
    output [20:0] romload_addr,
    output [20:0] sram_addr,
    output [ 7:0] sram_data,
    input  [20:0] game_addr,
    // 
    output reg    downloading
);

assign sram_addr = downloading ? romload_addr : game_addr;

parameter TX_LEN = 1024;

always @(posedge clk)
if(rst) begin
    downloading <= 1'b1;
    romload_addr   <= 21'd0;
    sram_we_n   <= 1'b1;
    sram_data   <= 8'd0;
    state       <= 
end else if(romload_addr!=TX_LEN) begin
        state <= state + 1;
        case( state )
            0: begin
                sram_data <= flash_data;
                sram_we_n <= 1'b0;
            end
            1: begin
                sram_we_n <= 1'b1;
                romload_addr <= romload_addr + 21'd1;
            end
        endcase // state
    end else begin // done!
        sram_we_n   <= 1'b1;
        downloading <= 1'b0;
    end



endmodule // jtgng_zxuno_prog