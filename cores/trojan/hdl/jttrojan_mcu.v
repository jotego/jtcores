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
    Date: 9-9-2024 */

// Following Trojan schematics, although it is not
// used in Trojan but Avengers

module jttrojan_mcu(
    input                rst,
    input                clk_rom,
    input                clk,
    input                cen,       //  6   MHz
    input                LVBL,
    input        [ 8:0]  vdump,
    // CPU interface
    input                mwr,
    input                mrd,
    output reg   [ 7:0]  to_main,
    input        [ 7:0]  from_main,

    input                swr,
    input                srd,
    output reg   [ 7:0]  to_snd,
    input        [ 7:0]  from_snd,
    // ROM programming
    input        [11:0]  prog_addr,
    input        [ 7:0]  prom_din,
    input                prom_we
);
`ifndef NOMCU
wire [ 7:0] p0_o, p2_o, p3_i, p3_o;
wire        ceng;
reg         int0n /* P32 */, int1n /* P33 */, p36l, g=1;

assign p3_i = {2'b11,~mrd,LVBL,LVBL,~mwr,1'b1,~srd};
assign ceng = cen & g; // this synchronization mechanism with the other
// two CPUs is required because the 8751 core used is not cycle accurate.
// If operated at the right speed, the MCU writes data to the main CPU
// one byte each 70us, whereas the CPU wants to read it one byte per 55.6us
// Some instructions, like INC DPTR, take too long on the 8751 core.
// The solution taken here is to operate the 8751 very fast but halt it when
// data has been written to the other CPUs. When data is read, the halt is
// released.

always @(posedge clk) begin
    p36l <= p3_o[6];
    if( p3_o[6] && !p36l ) begin
        to_main <= p0_o;
        to_snd  <= p2_o;
        g       <= 0;
    end
    if( mrd | srd ) g <= 1;
end

jtframe_8751mcu u_mcu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( ceng      ),
    // external memory: connected to main CPU
    .x_din      ( 8'd0      ),
    .x_dout     (           ),
    .x_addr     (           ),
    .x_wr       (           ),
    .x_acc      (           ),
    // interrupts
    .int0n      ( ~mwr      ), // P32
    .int1n      ( LVBL      ), // P33, /INT in sch, but it's basically LVBL
    // Ports
    .p0_i       ( from_main ),
    .p0_o       ( p0_o      ),

    .p1_i       ( vdump[7:0]),
    .p1_o       (           ),

    .p2_i       ( from_snd  ), // from sound CPU
    .p2_o       ( p2_o      ),

    .p3_i       ( p3_i      ),
    .p3_o       ( p3_o      ),

    .clk_rom    ( clk_rom   ),
    .prog_addr  ( prog_addr ),
    .prom_din   ( prom_din  ),
    .prom_we    ( prom_we   )
);
`else // NOMCU
    initial { to_main, to_snd } = 0;
`endif
endmodule