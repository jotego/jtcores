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
    Date: 19-3-2023 */

module jtngp_main(
    input               rst,
    input               clk,
    input               cen6,

    input               lvbl,

    input               start_button,
    input       [ 5:0]  joystick1,

    // Bus access
    output       [15:1] cpu_addr,
    output       [15:0] cpu_dout,
    input        [15:0] gfx_dout,
    input        [15:0] shd_dout,
    output       [ 1:0] we,
    output       [ 1:0] shd_we,

    output reg          gfx_cs,
    output              flash0_cs,
    output              flash1_cs,

    // Sound
    output reg          snd_nmi,
    output reg          snd_rstn,
    output reg          snd_en,
    input               snd_ack,
    output reg   [ 7:0] snd_dacl, snd_dacr,

    // Firmware access
    output              rom_cs,
    input        [15:0] rom_data,
    input               rom_ok
);

reg  [15:0] din;
wire [23:0] addr;
wire [15:0] ram0_dout, ram1_dout, io_dout;
reg         ram0_cs, ram1_cs,
            shd_cs,  io_cs,
            int4;
wire [ 1:0] ram0_we, ram1_we;
wire [ 3:0] map_cs;
wire        cpu_cen;
reg         poweron;
reg  [6:0]  pwr_cnt;

assign cpu_addr  = addr[15:1];
assign flash0_cs = map_cs[0], // in_range(24'h20_0000, 24'h40_0000);
       flash1_cs = map_cs[1]; // in_range(24'h80_0000, 24'hA0_0000);
assign ram0_we   = {2{ram0_cs}} & we,
       ram1_we   = {2{ram1_cs}} & we,
       shd_we    = {2{ shd_cs}} & we;
// to do: do we need to keep track of data written to the IO space in 80~C0?
assign io_dout   = addr[7:1]==7'b11_000 ? { 8'd3, 1'b0, ~poweron, ~joystick1 } : 16'd0;
assign cpu_cen   = (~rom_cs | rom_ok) & cen6;

function in_range( input [23:0] min, max );
    in_range = addr>=min && addr<max;
endfunction

always @* begin
    io_cs     = in_range(24'h00_0080, 24'h00_00c0);
    ram0_cs   = in_range(24'h00_4000, 24'h00_6000); //  8kB exclusive
    ram1_cs   = in_range(24'h00_6000, 24'h00_7000); //  4kB exclusive
    shd_cs    = in_range(24'h00_7000, 24'h00_8000); //  4kB shared
    gfx_cs    = in_range(24'h00_8000, 24'h00_c000); // 16kB GFX RAM
    rom_cs    = addr >= 24'hFF_0000;                // maybe map_cs[2/3] could be used too?
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        poweron <= 0;
        pwr_cnt <= 0;
    end else begin
        if( int4 && !poweron ) { poweron, pwr_cnt } <= { 1'b0, pwr_cnt } + 1'd1;
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd_rstn <= 0;
        snd_en   <= 0;
        snd_nmi  <= 0;
        snd_dacl <= 0;
        snd_dacr <= 0;
    end else begin
        if( snd_ack ) snd_nmi <= 0;
        if( io_cs ) begin
            // to do: 0xA0, 0xA1: write to t6w28 (sound generator) but Z80 takes precedence
            if( we[0] && addr[5:1]==5'b11_100 ) snd_en   <= cpu_dout[0]; // B8
            if( we[1] && addr[5:1]==5'b11_100 ) { snd_rstn, snd_nmi } <= { cpu_dout[8], 1'b0 }; // B9
            if( we[0] && addr[5:1]==5'b11_101 ) snd_nmi  <= 1;       // BA
            if( we[0] && addr[5:1]==5'b10_010 ) snd_dacr <= cpu_dout[ 7:0]; // B2
            if( we[1] && addr[5:1]==5'b10_010 ) snd_dacl <= cpu_dout[15:8]; // B3
        end
    end
end

always @(posedge clk) begin
    din <= gfx_cs  ? gfx_dout  :
           rom_cs  ? rom_data  :
           ram0_cs ? ram0_dout :
           ram1_cs ? ram1_dout :
           io_cs   ? io_dout :
           shd_cs  ? shd_dout  : 16'h0;
           // snd_cs   ?  :
end

jtframe_ram16 #(.AW(12)) u_ram0(
    .clk    ( clk           ),
    .data   ( cpu_dout      ),
    .addr   ( addr[12:1]    ),
    .we     ( ram0_we       ),
    .q      ( ram0_dout     )
);

jtframe_ram16 #(.AW(11)) u_ram1(
    .clk    ( clk           ),
    .data   ( cpu_dout      ),
    .addr   ( addr[11:1]    ),
    .we     ( ram1_we       ),
    .q      ( ram1_dout     )
);

jtframe_edge_pulse #(.NEGEDGE(1)) u_vblank(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .sigin  ( lvbl      ),
    .pulse  ( int4      )
);

jt95c061 u_mcu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cpu_cen   ),

    // interrupt sources
    .int4       ( int4      ),
    .nmi        ( poweron   ),

    .addr       ( addr      ),
    .din        ( din       ),
    .dout       ( cpu_dout  ),
    .we         ( we        ),

    .map_cs     ( map_cs    )
);

endmodule