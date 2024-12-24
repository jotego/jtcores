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

module jtcomsc_main_decoder(
    input               clk,        // 24 MHz
    input               rst,
    input               cpu_cen,
    input       [15:0]  A,
    input               RnW,
    input               VMA,
    output reg          gfx1_cs,
    output reg          gfx2_cs,
    output reg          pal_cs,
    output reg          prio_latch, // PRIONG    in schematics
    output reg  [ 7:0]  video_bank, // VCNG[7:0] in schematics
    // communication with sound CPU
    output reg          snd_irq,
    output reg  [ 7:0]  snd_latch,
    // ROM
    output reg  [17:0]  rom_addr,
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

reg         bank_cs,  vbank_cs, in_cs, gfx_cs, io_cs,
            sdata_cs, son_cs,   track_cs, dmp_cs;
reg  [ 3:0] bank;
reg  [ 7:0] port_in;
reg         bank_en; // called PBCANG in schematics
reg         video_sel;
wire [ 7:0] dmp_dout;

// K007556 decoder only looks at A15-A9
// second decoder for IOCS outputs then looks at A[4:2]
// but input /G2B could be A[5] as schematics scan don't show
// a horizontal band around that position
always @(*) begin
    rom_cs      = (A[15] || A[15:14]==2'b01) && VMA; // 4000-FFFF
    ram_cs      = A[15:12] == 4'b0001 || A[15:11]==5'b0000_1; // 800-1FFF - also RAM below it?
    // Line order important:
    io_cs       = A[15:9]==7'h2 && !A[5];  // 0400 - 041F
    //wdog_cs   = io_cs && A[4:2]==3'b111; // 041C
    sdata_cs    = io_cs && A[4:2]==3'b101; // 0414
    son_cs      = io_cs && A[4:2]==3'b110; // 0418
    bank_cs     = io_cs && A[4:2]==3'b100; // 0410
    vbank_cs    = io_cs && A[4:2]==3'b011; // 040C
    //out_cs      = io_cs && A[4:2]==3'b010; // 0408 - coin counters
    // coin counters will fall here, // 0408
    //track_cs    = io_cs && A[4:2]==3'b001; // 0404
    in_cs       = io_cs && A[4:3]==2'b00; // 0400

    gfx_cs      = A[15:13] == 3'b001 || A[15:9]==7'h0;
    gfx1_cs     = gfx_cs && !video_sel; // 2000-3FFF
    gfx2_cs     = gfx_cs &&  video_sel;
    dmp_cs      = A[15:9] == 7'h01; // 0200-0206
    pal_cs      = A[15:9] == 7'h03; // 0600-06FF
end

always @(*) begin
    case(1'b1)
        rom_cs:    cpu_din = rom_data;
        ram_cs:    cpu_din = ram_dout;
        pal_cs:    cpu_din = pal_dout;
        in_cs:     cpu_din = port_in;
        // track_cs:
        dmp_cs:    cpu_din = dmp_dout;
        gfx1_cs:   cpu_din = gfx1_dout;
        gfx2_cs:   cpu_din = gfx2_dout;
        default:   cpu_din = 8'hff;
    endcase
end

always @(*) begin
    if( A[15:14] == 2'b01 ) begin // banked
        if( bank_en )
            rom_addr = { 1'b0, bank[3:1], A[13:0] };
        else
            rom_addr = { 3'b100, bank[0], A[13:0] };
    end else begin // Non banked
        rom_addr = { 2'b10, A };
    end
end

always @(posedge clk) begin
    case( A[2:0] )
        3'b000: port_in <= {3'b111, coin, cab_1p[0], joystick1[5:4] };
        3'b001: port_in <= { dipsw_c, 1'b1, cab_1p[1], joystick2[5:4] };
        3'b010: port_in <= dipsw_a;
        3'b011: port_in <= dipsw_b;
        3'b100: port_in <= { joystick1[3:0], joystick2[3:0]};
        default: port_in <= 8'hff;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        video_sel  <= 0;
        prio_latch <= 0;
        bank_en    <= 0;
        bank       <= 4'd0;
        snd_irq    <= 0;
        snd_latch  <= 8'd0;
        video_bank <= 8'd0;
    end else if(cpu_cen) begin
        snd_irq <= son_cs;
        if( vbank_cs ) video_bank <= cpu_dout;
        if( bank_cs ) begin
            video_sel  <= cpu_dout[6];
            prio_latch <= cpu_dout[5];
            bank_en    <= cpu_dout[4];
            bank       <= cpu_dout[3:0];
        end
        if(sdata_cs) snd_latch <= cpu_dout;
    end
end

jtcontra_007452 u_div(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cs     ( dmp_cs & cpu_cen ),
    .wrn    ( RnW       ),
    .addr   ( A[2:0]    ),
    .din    ( cpu_dout  ),
    .dout   ( dmp_dout  )
);

endmodule