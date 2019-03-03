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
    input             rst,
    input             clk,
    // Flash
    input             flash_miso,
    output            flash_mosi,
    output            flash_clk,
    output reg        flash_cs_n,
    // SRAM
    output reg        sram_we_n,
    output reg [20:0] romload_addr,
    output     [20:0] sram_addr,
    output reg [ 7:0] sram_data,
    input      [20:0] game_addr8,
    //
    output reg        downloading
);

parameter flash_bank=24'h154_000; // bitstream 4
wire [23:0] flash_addr = { 3'd0, romload_addr } + flash_bank;

assign flash_mosi = flash_cmd[31];

assign sram_addr = downloading ? romload_addr : game_addr8;
reg [31:0] flash_cmd;
reg [ 7:0] flash_read;

always @(negedge clk)
    if(!flash_clk) flash_read <= { flash_read[6:0], flash_miso };

parameter TX_LEN = 1024;

reg [1:0] state;
reg [4:0] cnt;

always @(posedge clk)
if(rst) begin
    downloading <= 1'b1;
    romload_addr   <= 21'd0;
    flash_cs_n  <= 1'b1;
    flash_clk   <= 1'b0;
    sram_we_n   <= 1'b1;
    sram_data   <= 8'd0;
    state       <= 2'd0;
    cnt         <= 5'd0;
end else begin
    flash_clk <= ~flash_clk;
    if(romload_addr!=TX_LEN) begin
        if(cnt==5'd0) state <= state + 2'd1;
        case( state )
            2'd0: begin
                flash_cmd  <= { 8'h3, flash_addr };
                flash_cs_n <= 1'b0;
                cnt        <= 5'd31;
            end
            2'd1: begin // write command
                flash_cmd <= { flash_cmd[30:0], 1'b0 };
                cnt <= cnt!=5'd0 ? (cnt - 5'd1) : 5'd8;
            end
            2'd2: begin // wait data input
                if ( cnt!=5'd0 )
                    cnt<=cnt-5'd1;
                else begin
                    sram_data  <= flash_read;
                    sram_we_n  <= 1'b0;
                    flash_cs_n <= 1'b1;
                end
            end
            2'd3: begin
                sram_we_n <= 1'b1;
                romload_addr <= romload_addr + 21'd1;
            end
        endcase // state
    end else begin // done!
        sram_we_n   <= 1'b1;
        flash_cs_n  <= 1'b1;
        downloading <= 1'b0;
    end
end



endmodule // jtgng_zxuno_prog