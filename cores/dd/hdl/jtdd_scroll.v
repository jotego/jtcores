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
    Date: 2-12-2019 */

// Schematics 8/10 and 9/10 BACK
// Scroll layer


module jtdd_scroll(
    input              rst,
    input              clk,
    input              clk_cpu,
    (*direct_enable*)  input pxl_cen,
    input      [10:0]  cpu_AB,
    input              vram_cs,
    input              cpu_wrn,
    input      [ 7:0]  cpu_dout,
    output reg [ 7:0]  scr_dout,
    input      [ 7:0]  HPOS,
    input      [ 7:0]  VPOS,
    input      [ 8:0]  scrhpos,
    input      [ 8:0]  scrvpos,
    input              flip,
    // ROM access
    output reg [16:0]  rom_addr,
    input      [15:0]  rom_data,
    input              rom_ok,
    output reg [ 7:0]  scr_pxl
);

reg         hi_we, lo_we;
reg  [ 9:0] scan;
wire [ 7:0] hi_data, lo_data, cpu_hi, cpu_lo;
reg  [ 8:0] hscr, vscr;

always @(posedge clk) begin // may consider latching this if glitches appear
    hscr = {1'b0, HPOS} + scrhpos; // hscr[8] is latched in the original
    vscr = {1'b0, VPOS} + scrvpos;
end

always @(*) begin
    lo_we     = vram_cs && !cpu_wrn &&  cpu_AB[0];
    hi_we     = vram_cs && !cpu_wrn && !cpu_AB[0];
    scan      = { vscr[8], hscr[8], vscr[7:4], hscr[7:4] };
    scr_dout  = !cpu_AB[0] ? cpu_hi : cpu_lo;
end

`ifdef SIMULATION
reg scr_error;
`define SCR_ERROR scr_error<=~rom_ok;
`else
`define SCR_ERROR
`endif

reg  [15:0] shift;
reg  [ 3:0] pal, pal0;
reg         hflip, hflip0;
wire [ 3:0] mux = hflip0 ? shift[15:12] : shift[3:0]; //{shift[2], shift[3], shift[0], shift[1]};//shift[3:0];

// pixel output
always @(posedge clk) if(pxl_cen) begin
    scr_pxl  <= { pal0, mux };
    case( hscr[1:0] )
        2'b0: begin
            rom_addr  <= { hi_data[2:0], lo_data, vscr[3:0], hscr[3:2]^{2{hi_data[6]}} };
            pal       <= { hi_data[7], hi_data[5:3] }; // bit 7 affects priority
            pal0      <= pal;
            hflip0    <= hflip;
            hflip     <= hi_data[6] ^ flip;
            shift     <= {
                rom_data[15], rom_data[11], rom_data[7], rom_data[3],
                rom_data[14], rom_data[10], rom_data[6], rom_data[2],
                rom_data[13], rom_data[ 9], rom_data[5], rom_data[1],
                rom_data[12], rom_data[ 8], rom_data[4], rom_data[0] };
            `SCR_ERROR
        end
        default: begin
            shift    <= hflip0 ? (shift<<4) : (shift>>4);
        end
    endcase
end

jtframe_dual_ram #(.AW(10),.SIMFILE("scr_hi.bin")) u_ram_high(
    .clk0   ( clk_cpu     ),
    .data0  ( cpu_dout    ),
    .addr0  ( cpu_AB[10:1]),
    .we0    ( hi_we       ),
    .q0     ( cpu_hi      ),

    .clk1   ( clk         ),
    .data1  ( 8'd0        ),
    .addr1  ( scan        ),
    .we1    ( 1'b0        ),
    .q1     ( hi_data     )
);

jtframe_dual_ram #(.AW(10),.SIMFILE("scr_lo.bin")) u_ram_low(
    .clk0   ( clk_cpu     ),
    .data0  ( cpu_dout    ),
    .addr0  ( cpu_AB[10:1]),
    .we0    ( lo_we       ),
    .q0     ( cpu_lo      ),

    .clk1   ( clk         ),
    .data1  ( 8'd0        ),
    .addr1  ( scan        ),
    .we1    ( 1'b0        ),
    .q1     ( lo_data     )
);

endmodule