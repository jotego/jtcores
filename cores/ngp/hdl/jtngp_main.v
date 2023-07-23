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
    input               clk_rom,
    input               cen12,
    input               cen6,
    input               phi1_cen,
    input               rtc_cen,

    input               lvbl,

    input               start_button,
    input               pwr_button,
    input       [ 5:0]  joystick1,

    // Bus access
    output       [20:1] cpu_addr,
    output       [15:0] cpu_dout,
    input        [15:0] gfx_dout,
    input        [15:0] shd_dout,
    output       [ 1:0] we,
    output       [ 1:0] shd_we,

    output reg          gfx_cs,
    output reg          flash0_cs,
    input               flash0_rdy,
    input        [15:0] flash0_dout,
    output reg          flash1_cs,

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
    input               rom_ok,

    // NVRAM
    input        [13:0] ioctl_addr,
    input        [ 7:0] ioctl_dout,
    output reg   [ 7:0] ioctl_din,
    input               ioctl_ram,
    input               ioctl_wr,
    // Debug
    input        [ 7:0] debug_bus,
    output reg   [ 7:0] st_dout
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
wire [ 7:0] rtc_sec, rtc_min, rtc_hour;
wire [ 2:0] rtc_we;

// NVRAM
wire        nvram0_we, nvram1_we;
wire [ 7:0] nvram0_dout, nvram1_dout;

wire [ 7:0] st_cpu;

assign bus_busy  = (rom_cs & ~rom_ok) | (flash0_cs & ~flash0_rdy);
assign cpu_addr  = addr[20:1];
// assign flash0_cs = map_cs[0], // in_range(24'h20_0000, 24'h40_0000);
//        flash1_cs = map_cs[1]; // in_range(24'h80_0000, 24'hA0_0000);
assign ram0_we   = {2{ram0_cs}} & we,
       ram1_we   = {2{ram1_cs}} & we,
       shd_we    = {2{ shd_cs}} & we;
// assign cpu_clk   = cpu_cen & clk;
assign snd_irq   = porta_dout[3];
assign rtc_we[2] = io_cs && we[0] && addr[5:1]==5'b01_010; // 80+14 = 94 - hours
assign rtc_we[1] = io_cs && we[1] && addr[5:1]==5'b01_010; // 80+15 = 95 - minutes
assign rtc_we[0] = io_cs && we[0] && addr[5:1]==5'b01_011; // 80+16 = 96 - seconds

assign nvram0_we = ioctl_ram & ioctl_wr & ~ioctl_addr[13];
assign nvram1_we = ioctl_ram & ioctl_wr &  ioctl_addr[13];
// always @(negedge clk) cpu_cen <= (~rom_cs | rom_ok) & ~cpu_cen;

always @(posedge clk) begin
    st_dout <= joystick1[4] ? st_cpu : ngp_ports[debug_bus[5:0]];
end

function in_range( input [23:0] min, max );
    in_range = addr>=min && addr<max;
endfunction

always @* begin
    io_dout = { ngp_ports[{addr[5:1],1'b1}], ngp_ports[{addr[5:1],1'b0}] };
    case( addr[5:1] )
        5'b01_010: io_dout = { rtc_min, rtc_hour }; // 94-95
        5'b01_011: io_dout[7:0] = rtc_sec;          // 96
        5'b11_000: io_dout = { 7'b1,
                               1'b0, // power button: it should be zero for it to power up
             /* lower byte: */ 2'd0, ~joystick1 }; // B0-B1
        5'b11_110: io_dout = { 8'd0, main_latch}; //  BC - written by the z80
        default:;
    endcase
end

always @* begin
    io_cs     = in_range(24'h00_0080, 24'h00_00c0);
    ram0_cs   = in_range(24'h00_4000, 24'h00_6000); //  8kB exclusive
    ram1_cs   = in_range(24'h00_6000, 24'h00_7000); //  4kB exclusive
    shd_cs    = in_range(24'h00_7000, 24'h00_8000); //  4kB shared
    gfx_cs    = in_range(24'h00_8000, 24'h00_c000); // 16kB GFX RAM
    flash0_cs = in_range(24'h20_0000, 24'h40_0000);
    flash1_cs = in_range(24'h80_0000, 24'hA0_0000);
    rom_cs    = addr >= 24'hFF_0000;                // maybe map_cs[2/3] could be used too?
end

always @(posedge clk) ioctl_din <= ioctl_addr[13] ? nvram1_dout : nvram0_dout;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        poweron <= 0; // power-on button press not needed when using a NVRAM file
        pwr_cnt <= 8;
    end else begin
        if( int4 && !poweron ) { poweron, pwr_cnt } <= { 1'b0, pwr_cnt } + 1'd1;
        if( !pwr_button ) begin
            poweron <= 0;
            pwr_cnt <= 8;
        end
    end
end
`ifdef SIMULATION
    reg locked = 0;
    reg [23:0] last_addr = addr;

    // synchronize VB with MAME
    always @(posedge clk) begin
        last_addr <= addr;
        if( addr==23'h20015A && addr!=last_addr ) locked <= 1;
        if( !lvbl ) locked <= 0;
    end
`endif
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd_rstn <= 0;
        snd_en   <= 0;
        snd_nmi  <= 0;
        snd_dacl <= 0;
        snd_dacr <= 0;
`ifdef NVRAM
        // RTC values at start up
        ngp_ports['h11] = 8'h98; // year
        ngp_ports['h12] = 8'h01; // month
        ngp_ports['h13] = 8'h01; // day
        ngp_ports['h17] = 8'h24; // hour format?
`endif
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
    din =  gfx_cs    ? gfx_dout    :
           rom_cs    ? rom_data    :
           ram0_cs   ? ram0_dout   :
           ram1_cs   ? ram1_dout   :
           io_cs     ? io_dout     :
           flash0_cs ? flash0_dout :
           shd_cs    ? shd_dout    : 16'h0;
end
/* verilator tracing_off */
jtframe_rtc u_rtc(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .cen    ( rtc_cen       ),   // 1-second clock enable
    .din    ( cpu_dout[7:0] ),
    .we     ( rtc_we        ),    // overwrite hour, min, sec
    .sec    ( rtc_sec       ),
    .min    ( rtc_min       ),
    .hour   ( rtc_hour      )
);

/* verilator tracing_on */
jtframe_dual_nvram16 #(
    .AW(12)     // 8kB
`ifdef DUMP_RAM
    ,.VERBOSE(1),.VERBOSE_OFFSET('h4000) `endif
) u_ram0(
    .clk0   ( clk           ),
    .data0  ( cpu_dout      ),
    .addr0  ( addr[12:1]    ),
    .we0    ( ram0_we       ),
    .q0     ( ram0_dout     ),
    // memory dump
    .clk1   ( clk_rom       ),
    .addr1a ( 12'd0         ),
    .q1a    (               ),
    .addr1b (ioctl_addr[12:0]),
    .data1  ( ioctl_dout    ),
    .sel_b  ( 1'b1          ),
    .we1b   ( nvram0_we     ),
    .q1b    ( nvram0_dout   )
);

`ifdef SIMULATION
    reg flash0_csl, flash0_msg = 0;
    always @(posedge clk) begin
        flash0_csl <= flash0_cs;
        if( flash0_cs && !flash0_csl && !flash0_msg ) begin
            flash0_msg <= 1;
            $display("Flash accessed");
        end
    end
`endif

`ifdef TRACE
// for trace comparisons with MAME, swap the RAM memory contents at a given frame
    reg [11:0] over_k=0;
    reg [ 7:0] over_data[0:2**12-1];
    reg        copy=0, copy_done=0, lvbl_l, halted_l;
    wire       copy_bsy = copy & ~copy_done;
    integer framecnt=1, f, fcnt;

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


    always @(posedge clk) begin
        lvbl_l <= lvbl;
        halted_l <= u_mcu.u_cpu.u_ctrl.halted;
        if( /*u_mcu.u_cpu.u_ctrl.halted && !halted_l &&*/ flash0_cs && framecnt>=`TRACE && !copy_done && !copy ) begin
            copy   <= 1;
            $display("ram1 overwrite starts");
        end
        if( !lvbl && lvbl_l ) begin
            framecnt <= framecnt+1;
        end
        if( copy && !copy_done ) begin
            { copy_done, over_k } <= { copy_done, over_k } + 1'd1;
        end
    end
`else
    wire copy=0, copy_done=0, copy_bsy=0;
`endif

wire [15:0] r6c18;

jtframe_dual_nvram16 #(
    .AW(11)     // 4kB
`ifdef DUMP_RAM
    ,.VERBOSE(1),.VERBOSE_OFFSET('h6000) `endif
) u_ram1(
    .clk0   ( clk           ),
    .data0  ( cpu_dout      ),
    .addr0  ( addr[11:1]    ),
    .we0    ( ram1_we       ),
    .q0     ( ram1_dout     ),
    // memory dump
    .addr1a ( 11'h60c       ), // 6c18 >> 1
    .q1a    ( r6c18         ),
    .q1b    ( nvram1_dout   ),
`ifdef TRACE
    // memory overwrite
    .clk1   ( clk           ),
    .sel_b  ( copy_bsy      ),
    .addr1b ( over_k        ),
    .data1  ( over_data[over_k] ),
    .we1b   ( copy_bsy )
`else
    .clk1   ( clk_rom       ),
    .sel_b  ( 1'b1          ),
    .addr1b (ioctl_addr[11:0]),
`ifdef SIMULATION    // for sims, NVRAM is supported to skip the set up menu
    .data1  ( ioctl_dout    ),
    .we1b   ( nvram1_we     )
`else // for compilation, delete the RAM when something is loaded
    .data1  ( 8'd0          ),
    .we1b   ( ioctl_wr      )
`endif
`endif
);

jtframe_edge_pulse #(.NEGEDGE(1)) u_vblank(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .sigin  ( lvbl      ),
    .pulse  ( int4      )
);
/* verilator tracing_on */

jt95c061 u_mcu(
    .rst        ( rst       ),
    .clk        ( clk       ),
`ifdef SIMULATION
    .cen        ( cen12 & ~(copy^copy_done) & ~locked  ),  // this is still too slow...
`else
    .cen        ( cen12     ),
`endif
    .phi1_cen   ( phi1_cen  ),

    // interrupt sources
    .int4       ( int4      ),
    .int5       ( main_int5 ),
`ifdef NVRAM
    .nmi        ( 1'b0      ),
`else
    .nmi        ( poweron   ), // should this be gated by bit mmr[0x33][2] ?
`endif
    .porta_dout ( porta_dout),

    .addr       ( addr      ),
    .din        ( din       ),
    .dout       ( cpu_dout  ),
    .we         ( we        ),
    .bus_busy   ( bus_busy  ),

    .map_cs     ( map_cs    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_cpu    )
); // NOMAIN
`else
    assign { cpu_addr, cpu_dout, we, shd_we, flash0_cs, flash1_cs, snd_irq } = 0;
    initial begin
        snd_rstn = 1;
        { gfx_cs, snd_nmi, snd_en, snd_latch, snd_dacl, snd_dacr, rom_cs } = 0;
    end
`endif
endmodule