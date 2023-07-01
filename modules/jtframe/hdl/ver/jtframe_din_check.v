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
    Date: 16-9-2019 */

// Verifies that values read by the SDRAM controller
// match the file contents

module jtframe_din_check #(parameter
    DW=16,
    AW=18,
    HEXFILE="sdram.hex"
)(
    input            rst,
    input            clk,
    input            cen,
    input            rom_cs,
    input            rom_ok,
    input   [AW-1:0] rom_addr,
    input   [DW-1:0] rom_data,
    output reg       error=1'b0
);

reg [DW-1:0]  good_rom[0:2**AW-1];
wire [DW-1:0] good_data = good_rom[rom_addr];
wire good = rom_data == good_data;

initial begin
    $readmemh(HEXFILE, good_rom);
end


always @(posedge clk, posedge rst) begin
    if( rst )
        error <= 1'b0;
    else if(cen) begin
        if( rom_cs && rom_ok) begin
            error <= !good;
            if( !good ) begin
                $display("ERROR: SDRAM read error at time %t",$time);
                #40_000_000 $finish;
            end
        end
    end
end

endmodule