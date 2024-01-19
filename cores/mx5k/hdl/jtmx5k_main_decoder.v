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
    Date: 21-8-2021 */

module jtmx5k_main_decoder(
    input               clk,        // 24 MHz
    input               rst,
    input               cpu_cen,
    input       [15:0]  A,
    input               VMA,
    input               RnW,
    output reg          gfx1_cs,
    input               pal_cs, // from 007121
    // communication with sound CPU
    output reg          snd_irq,
    output reg  [ 7:0]  snd_latch,
    // ROM
    output reg  [15:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,
    // cabinet I/O
    input       [ 1:0]  cab_1p,
    input       [ 1:0]  coin,
    input       [ 6:0]  joystick1,
    input       [ 6:0]  joystick2,
    input               service,
    // Data
    input       [ 7:0]  cpu_dout,
    input       [ 7:0]  pal_dout,
    input       [ 7:0]  gfx1_dout,
    output reg          ram_cs,
    output reg  [ 7:0]  cpu_din,
    input       [ 7:0]  ram_dout,
    // DIP switches
    input       [ 7:0]  dipsw_a,
    input       [ 7:0]  dipsw_b,
    input       [ 3:0]  dipsw_c
);

reg        io_cs;
reg  [1:0] bank;
reg  [7:0] port_in;
wire [7:0] div_dout;

always @(*) begin // Decoder 051502 takes as inputs A[15:10]
    rom_cs   = A[15:12]>=4 && RnW && VMA;
    io_cs    = A[15:10]==1;
    ram_cs   = A[15:12] == 3;
    gfx1_cs  = A[15:12] < 3 && !io_cs;
    rom_addr = A[15:12]>=6 ? A[15:0] : { A[15], bank, A[12:0] };
end

always @(*) begin
    case(1'b1)
        rom_cs:  cpu_din = rom_data;
        ram_cs:  cpu_din = ram_dout;
        io_cs:   cpu_din = port_in;
        gfx1_cs: cpu_din = pal_cs ? pal_dout : gfx1_dout;
        default: cpu_din = 8'hff;
    endcase
end

always @(*) begin
    case( A[4:2] )
        0:  case( A[1:0] )
                0: port_in = {2'b11, joystick1[5:4], joystick1[2], joystick1[3], joystick1[0], joystick1[1]};
                1: port_in = {2'b11, joystick2[5:4], joystick2[2], joystick2[3], joystick2[0], joystick2[1]};
                2: port_in = {2'b11, joystick2[6],   joystick1[6], dipsw_c[3:0] };
                3: port_in = {3'b111, cab_1p, service, coin };
            endcase
        1: port_in = A[0] ? dipsw_a : dipsw_b;
        default: port_in = 8'hFF;
    endcase
end

// unknown usage, it's related to generating the CS signals in
// the original PCB but doesn't seem really needed
reg net_nrd, net_wowr;
reg net_end;            // seems to be a JAMMA pin

always @(posedge clk) begin
    if( rst ) begin
        bank      <= 0;
        snd_irq   <= 0;
        snd_latch <= 0;
    end else if(cpu_cen) begin
        snd_irq   <= 0;
        if( io_cs && !RnW ) begin
            case( A[4:2] ) // 5D in schematics
                4: begin
                    net_wowr <= cpu_dout[7]; // this seems related to gfx1/2_cs
                    net_nrd  <= cpu_dout[6];
                    net_end  <= cpu_dout[5];
                    bank <= cpu_dout[1:0];
                end
                // 2'b00: coin counters
                5: snd_latch <= cpu_dout;
                6: snd_irq   <= 1;
                // 7: watchdog
            endcase
        end
    end
end

endmodule