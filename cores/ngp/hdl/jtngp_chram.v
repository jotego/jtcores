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

    Author: Jose Tejada Gomez. https://patreon.com/jotego
    Version: 1.0
    Date: 22-3-2022 */

module jtngp_chram(
    input             rst,
    input             clk,
    // CPU access
    input      [12:1] cpu_addr,
    output     [15:0] cpu_din,
    input      [15:0] cpu_dout,
    input      [ 1:0] dsn,
    input             ram_cs,
    // video access
    input             obj_rd,
    output reg        obj_ok,
    input      [12:1] obj_addr,
    output reg [15:0] obj_data,

    input      [12:1] scr1_addr,
    output reg [15:0] scr1_data,

    input      [12:1] scr2_addr,
    output reg [15:0] scr2_data
);

wire [1:0] we;
reg  [12:1] chram_addr;
wire [15:0] chram_dout;
reg  [ 1:0] st;

assign we = ~dsn & {2{ram_cs}};

always @* begin
    case( st )
        0: chram_addr = scr1_addr;
        2: chram_addr = scr2_addr;
        default: chram_addr = obj_addr;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st     <= 0;
        obj_ok <= 0;
    end else begin
        st <= st+2'd1;
        if( !obj_rd ) obj_ok <= 0;
        case( st )
            1: scr1_data <= chram_dout;
            3: scr2_data <= chram_dout;
            default: begin
                obj_data <= chram_dout;
                obj_ok <= obj_rd;
            end
        endcase
    end
end
`ifdef SIMULATION
reg [15:0] chk_d=0;
reg [12:1] chk_a=0;
always @(posedge clk) if(we!=0) { chk_a, chk_d } <= { cpu_addr, cpu_dout & {{8{we[1]}},{8{we[0]}}} };
`endif
jtframe_dual_ram16 #(
    .AW         ( 12            ),  // 4kB
    .SIMFILE_LO ("ch_lo.bin"    ),
    .SIMFILE_HI ("ch_hi.bin"    )
) u_chram(
    // Port 0
    .clk0   ( clk        ),
    .data0  ( cpu_dout   ),
    .addr0  ( cpu_addr   ),
    .we0    ( we         ),
    .q0     ( cpu_din    ),
    // Port 1
    .clk1   ( clk        ),
    .data1  (            ),
    .addr1  ( chram_addr ),
    .we1    ( 2'b0       ),
    .q1     ( chram_dout )
);

endmodule