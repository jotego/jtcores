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
    Date: 8-9-2025 */

// Simple SRAM interface. Generates an ok signals after 3 clock cycles
// which at 48MHz = 65.5ns, above the 55ns minimum set by the data sheet
module jtframe_pocket_sram(
    input             clk,  // use only 48MHz clock
    // core
    input     [16:0]  addr,
    input     [15:0]  din,
    output reg[15:0]  dout,
    input             wen,
    input     [ 1:0]  dsn,
    output            ok,   // takes 1 tick to go down after a request
    // Pins
    output    [16:0]  pin_a,
    inout     [15:0]  pin_dq,
    output            pin_oe_n,
    output            pin_we_n,
    output            pin_ub_n,
    output            pin_lb_n
);

localparam OK=2;

reg [16:0] addr_l;
reg [OK:0] ok_sh;
reg        wen_l;
wire       req;

assign req      = addr_l!=addr || wen_l!=wen;
assign ok       = ok_sh[OK];
// SRAM pins
assign pin_a    = addr;
assign pin_dq   = wen ? 16'hzzzz : din;
assign {pin_ub_n,pin_lb_n} = dsn;
assign pin_we_n = wen;
assign pin_oe_n =~wen;

always @(posedge clk) begin
    dout <= pin_dq;
end

always @(posedge clk) begin
    addr_l <= addr;
    wen_l  <= wen;
    if(req) begin
        ok_sh <= 1;
    end else begin
        ok_sh    <= ok_sh << 1;
        ok_sh[0] <= 1;
    end
end

endmodule
