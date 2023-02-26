/*  This file is part of JTDD.
    JTDD program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTDD program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTDD.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2-12-2019 */

// Schematcics 4/9 MAP
// Character layer


module jtdd_char(
    input              clk,
    input              rst,
    (*direct_enable*)  input pxl_cen,
    input      [10:0]  cpu_AB,
    input              char_cs,
    input              cpu_wrn,
    input      [ 7:0]  cpu_dout,
    input              cen_Q,
    output reg [ 7:0]  char_dout,
    input      [ 7:0]  HPOS,
    input      [ 7:0]  VPOS,
    input              flip,
    // ROM access
    output reg [15:0]  rom_addr,
    input      [ 7:0]  rom_data,
    input              rom_ok,
    output reg [ 6:0]  char_pxl
);

reg         hi_we, lo_we;
reg  [ 9:0] scan;
wire [ 7:0] hi_data, lo_data, cpu_hi, cpu_lo;
wire [ 7:0] hi_dout, lo_dout, hi_msg, lo_msg;

assign hi_data = hi_dout;
assign lo_data = lo_dout;

always @(*) begin
    lo_we     = cen_Q && char_cs && !cpu_wrn &&  cpu_AB[0];
    hi_we     = cen_Q && char_cs && !cpu_wrn && !cpu_AB[0];
    scan      = { VPOS[7:3], HPOS[7:3] };
    // ram_addr  = HPOS[0] ? cpu_AB[12:1] : scan;
    char_dout = !cpu_AB[0] ? cpu_hi : cpu_lo;
end

reg  [7:0] shift;
reg  [2:0] pal, pal0;
wire [3:0] mux = flip ? shift[7:4] : shift[3:0];

`ifdef SIMULATION
reg char_error;
`define ROM_ERROR char_error<=~rom_ok;
`else
`define ROM_ERROR 
`endif

always @(posedge clk) if(pxl_cen) begin
    char_pxl  <= { pal0, mux };
    case( HPOS[0] ) 
        1'b0: begin// 01
            // Double Dragon 1 only uses hi_data[1:0], but filling up for compatibility with DD2
            rom_addr <= { hi_data[2:0], lo_data, VPOS[2:0], HPOS[2:1] };
            pal       <= hi_data[7:5];
            pal0      <= pal;
            shift     <= { 
                rom_data[7], rom_data[5], rom_data[3], rom_data[1],
                rom_data[6], rom_data[4], rom_data[2], rom_data[0] };
            `ROM_ERROR
        end
        1'b1: begin
            shift <= flip ? (shift<<4) : (shift >> 4);
        end
    endcase
end

jtframe_dual_ram #(.AW(10),.SIMFILE("char_hi.bin")) u_ram_high(
    .clk0   ( clk         ),
    .data0  ( cpu_dout    ),
    .addr0  ( cpu_AB[10:1]),
    .we0    ( hi_we       ),
    .q0     ( cpu_hi      ),

    .clk1   ( clk         ),
    .data1  ( 8'd0        ),
    .addr1  ( scan        ),
    .we1    ( 1'b0        ),
    .q1     ( hi_dout     )
);

jtframe_dual_ram #(.AW(10),.SIMFILE("char_lo.bin")) u_ram_low(
    .clk0   ( clk         ),
    .data0  ( cpu_dout    ),
    .addr0  ( cpu_AB[10:1]),
    .we0    ( lo_we       ),
    .q0     ( cpu_lo      ),

    .clk1   ( clk         ),
    .data1  ( 8'd0        ),
    .addr1  ( scan        ),
    .we1    ( 1'b0        ),
    .q1     ( lo_dout     )
);

endmodule