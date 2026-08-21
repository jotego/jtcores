/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-9-2019 */

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


always @(posedge clk) begin
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