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
    Date: 29-6-2020 */

// Clocks are derived from H counter on the original PCB
// Yet, that doesn't seem to be important and it only
// matters the frequency of the signals:
// E,Q: 3 MHz
// Q is 1/4th of wave advanced

module jtcontra_main_decoder(
    input               clk,        // 24 MHz
    input               rst,
    input               cpu_cen,
    input       [15:0]  A,
    input               VMA,
    input               RnW,
    input               gfx1_cs,
    input               gfx2_cs,
    output reg          pal_cs,
    // communication with sound CPU
    output reg          snd_irq,
    output reg  [ 7:0]  snd_latch,
    // ROM
    output reg  [16:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,
    // cabinet I/O
    input       [ 1:0]  cab_1p,
    input       [ 1:0]  coin,
    input       [ 5:0]  joystick1,
    input       [ 5:0]  joystick2,
    input               service,
    // Data
    input       [ 7:0]  cpu_dout,
    input       [ 7:0]  pal_dout,
    input       [ 7:0]  gfx1_dout,
    input       [ 7:0]  gfx2_dout,
    output reg          ram_cs,
    output reg  [ 7:0]  cpu_din,
    input       [ 7:0]  ram_dout,
    // DIP switches
    input      [7:0]    dipsw_a,
    input      [7:0]    dipsw_b,
    input      [3:0]    dipsw_c
);

reg        bank_cs, in_cs, out_cs, div_cs;
reg  [3:0] bank;
reg  [7:0] port_in;
wire [7:0] div_dout;

always @(*) begin // Decoder 007766 takes as inputs A[15:10] and A[6:5]
    rom_cs      = (A[15] || A[15:13]==3'b011) && RnW && VMA;
    bank_cs     = A[15:12] == 4'b0111 && !RnW;
    ram_cs      = A[15:12] == 4'b0001;
    pal_cs      = A[15:10] == 6'b0000_11;
    div_cs      = A[15:10] == 6'b0000_00 && A[6:4]==0 && A[3];  // 08-0F
    in_cs       = A[15:10] == 6'b0000_00 && A[6:4]==1 &&  RnW;  // 10 -1F
    out_cs      = A[15:10] == 6'b0000_00 && A[6:4]==1 && !RnW;  // 18-1F
end

always @(*) begin
    case(1'b1)
        rom_cs:  cpu_din = rom_data;
        ram_cs:  cpu_din = ram_dout;
        pal_cs:  cpu_din = pal_dout;
        in_cs:   cpu_din = port_in;
        div_cs:  cpu_din = div_dout;    // must be above gfx?_cs as it gets selected at the same time
        gfx1_cs: cpu_din = gfx1_dout;
        gfx2_cs: cpu_din = gfx2_dout;
        default: cpu_din = 8'hff;
    endcase
end

always @(*) begin
    rom_addr = A[15] ? { 2'b11, A[14:0] } : { bank, A[12:0] }; // 13+4=17
end

always @(posedge clk) begin
    case( A[2:0] )
        3'b000: port_in <= {3'b111, cab_1p, service, coin };
        3'b001: port_in <= {2'b11, joystick1[5:4], joystick1[2], joystick1[3], joystick1[0], joystick1[1]};
        3'b010: port_in <= {2'b11, joystick2[5:4], joystick2[2], joystick2[3], joystick2[0], joystick2[1]};
        3'b100: port_in <= dipsw_a;
        3'b101: port_in <= dipsw_b;
        3'b110: port_in <= { 4'hf, dipsw_c };
        default: port_in <= 8'hFF;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        bank      <= 4'd0;
        snd_irq   <= 0;
        snd_latch <= 8'd0;
    end else if(cpu_cen) begin
        snd_irq   <= 0;
        if( bank_cs ) bank <= cpu_dout[3:0];
        if( out_cs  ) begin
            case( A[3:1] ) // 14D in schematics
                // 2'b00: coin counters
                5: snd_irq   <= 1;
                6: snd_latch <= cpu_dout;
                // 2'b11 watchdog
            endcase
        end
    end
end

jtcontra_007452 u_div(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cs     ( div_cs & cpu_cen ),
    .wrn    ( RnW       ),
    .addr   ( A[2:0]    ),
    .din    ( cpu_dout  ),
    .dout   ( div_dout  )
);

endmodule