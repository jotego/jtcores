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
    input               cen24,
    input               cen12,
    input               cen6,
    input               phi1_cen,

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
    output              snd_irq,
    output reg          snd_rstn,
    output reg          snd_en,
    input               snd_ack,
    input               main_int5,
    output reg   [ 7:0] snd_latch,
    input        [ 7:0] main_latch,
    output reg   [ 7:0] snd_dacl, snd_dacr,

    // Firmware access
    output reg          rom_cs,
    input        [15:0] rom_data,
    input               rom_ok
);
`ifndef NOMAIN
reg  [15:0] din;
wire [23:0] addr;
wire [15:0] ram0_dout, ram1_dout;
reg  [15:0] io_dout;
reg         ram0_cs, ram1_cs,
            shd_cs,  io_cs;
reg  [ 7:0] ngp_ports[0:63]; // mapped to 80~BF
wire [ 1:0] ram0_we, ram1_we;
wire [ 3:0] map_cs;
wire        int4;
// reg         cpu_cen=0;
reg         poweron;
reg  [ 3:0] pwr_cnt;
wire [ 3:0] porta_dout;
wire        bus_busy;

assign bus_busy  = rom_cs & ~rom_ok;
assign cpu_addr  = addr[15:1];
assign flash0_cs = map_cs[0], // in_range(24'h20_0000, 24'h40_0000);
       flash1_cs = map_cs[1]; // in_range(24'h80_0000, 24'hA0_0000);
assign ram0_we   = {2{ram0_cs}} & we,
       ram1_we   = {2{ram1_cs}} & we,
       shd_we    = {2{ shd_cs}} & we;
// assign cpu_clk   = cpu_cen & clk;
assign snd_irq   = porta_dout[3];

// always @(negedge clk) cpu_cen <= (~rom_cs | rom_ok) & ~cpu_cen;

function in_range( input [23:0] min, max );
    in_range = addr>=min && addr<max;
endfunction

always @* begin
    case( addr[5:1] )
        5'b11_000: io_dout = { 7'b1,
                               1'b0, // power button: it should be zero for it to power up
             /* lower byte: */ 2'd0, ~joystick1 }; // B0-B1
        5'b11_110: io_dout = { 8'd0, main_latch}; // written by the z80
        default:   io_dout = { ngp_ports[{addr[5:1],1'b1}], ngp_ports[{addr[5:1],1'b0}] };
    endcase
end

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
        pwr_cnt <= 8;
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
            if( we[0] && addr[5:1]==5'b10_001 ) snd_dacr <= cpu_dout[ 7:0]; // A2
            if( we[1] && addr[5:1]==5'b10_001 ) snd_dacl <= cpu_dout[15:8]; // A3
            if( we[0] && addr[5:1]==5'b11_100 ) snd_en   <= cpu_dout[0]; // B8
            if( we[1] && addr[5:1]==5'b11_100 ) { snd_rstn, snd_nmi } <= { cpu_dout[8], 1'b0 }; // B9
            if( we[0] && addr[5:1]==5'b11_101 ) snd_nmi  <= 1;       // BA
            if( we[0] && addr[5:1]==5'b11_110 ) snd_latch <= cpu_dout[7:0]; // BC
            // assume that all ports are readable back
            if( we[0] ) ngp_ports[ { addr[5:1],1'b0} ] <= cpu_dout[ 7:0];
            if( we[1] ) ngp_ports[ { addr[5:1],1'b1} ] <= cpu_dout[15:8];
        end
    end
end

always @* begin
    din =  gfx_cs  ? gfx_dout  :
           rom_cs  ? rom_data  :
           ram0_cs ? ram0_dout :
           ram1_cs ? ram1_dout :
           io_cs   ? io_dout :
           shd_cs  ? shd_dout  : 16'h0;
           // snd_cs   ?  :
end

jtframe_ram16 #(
    .AW(12)
`ifdef DUMP_RAM
    ,.VERBOSE(1),.VERBOSE_OFFSET('h4000) `endif
) u_ram0(
    .clk    ( clk           ),
    .data   ( cpu_dout      ),
    .addr   ( addr[12:1]    ),
    .we     ( ram0_we       ),
    .q      ( ram0_dout     )
);

// jtframe_ram16 #(
//     .AW(11)     // 4kB
// `ifdef DUMP_RAM
//     ,.VERBOSE(1),.VERBOSE_OFFSET('h6000) `endif
// ) u_ram1(
//     .clk    ( clk           ),
//     .data   ( cpu_dout      ),
//     .addr   ( addr[11:1]    ),
//     .we     ( ram1_we       ),
//     .q      ( ram1_dout     )
// );
`ifdef SIMULATION
    wire [15:0] over16;
    reg [11:1] over_k;
    reg [7:0] over_data[0:2**12-1];
    reg lvbl_l, halted_l;
    reg copy=0;
    integer framecnt, f, fcnt;

    initial begin
        f=$fopen("ram1.bin","rb");
        if( f!=0 ) begin
            fcnt=$fread(over_data,f);
            $display("Read %X bytes from ram1.bin",fcnt);
            $fclose(f);
        end else begin
            $display("Cannot open ram1.bin");
            $finish;
        end
    end

    assign over16 = { over_data[{over_k,1'b1}], over_data[{over_k,1'b0}] };

    always @(posedge clk) begin
        lvbl_l <= lvbl;
        halted_l <= u_mcu.u_cpu.u_ctrl.halted;
        if( u_mcu.u_cpu.u_ctrl.halted && !halted_l && framecnt==524 ) begin
            copy   <= 1;
            over_k <= 0;
            $display("ram1 overwrite starts");
        end
        if( !lvbl && lvbl_l ) begin
            framecnt <= framecnt+1;
        end
        if( copy ) begin
            { copy, over_k } <= { copy, over_k } + 1'd1;
        end
    end
`else
    wire [15:0] over_data = 0;
    wire [11:1] over_k = 0;
    wire        copy = 0;
`endif

jtframe_dual_ram16 #(
    .AW(11)     // 4kB
`ifdef DUMP_RAM
    ,.VERBOSE(1),.VERBOSE_OFFSET('h6000) `endif
) u_ram1(
    .clk0   ( clk           ),
    .data0  ( cpu_dout      ),
    .addr0  ( addr[11:1]    ),
    .we0    ( ram1_we       ),
    .q0     ( ram1_dout     ),
    // memory overwrite
    .clk1   ( clk           ),
    .data1  ( over16        ),
    .addr1  ( over_k[11:1]  ),
    .we1    ( {2{copy}}     ),
    .q1     (               )
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
    .cen        ( cen12     ),  // this is still too slow...
    .phi1_cen   ( phi1_cen  ),

    // interrupt sources
    .int4       ( int4      ),
    .int5       ( main_int5 ),
    .nmi        ( poweron   ),
    .porta_dout ( porta_dout),

    .addr       ( addr      ),
    .din        ( din       ),
    .dout       ( cpu_dout  ),
    .we         ( we        ),
    .bus_busy   ( bus_busy  ),

    .map_cs     ( map_cs    )
); // NOMAIN
`else
    assign { cpu_addr, cpu_dout, we, shd_we, flash0_cs, flash1_cs, snd_irq } = 0;
    initial begin
        snd_rstn = 1;
        { gfx_cs, snd_nmi, snd_en, snd_latch, snd_dacl, snd_dacr, rom_cs } = 0;
    end
`endif
endmodule