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
    Date: 15-11-2025 */

module jtcal50_main(
    input                rst, clk, pxl_cen,
    input                lvbl, cen244,

    output        [19:1] rom_addr,
    output        [12:0] cpu_addr,
    output        [ 1:0] ram_dsn,
    output               ram_we,
    output        [15:0] cpu_dout,

    // 8-bit interface
    output               cpu_rnw,
    // Sound interface
    output        [ 7:0] snd_cmd,
    input         [ 7:0] snd_rply,

    output reg           rom_cs,
    output reg           ram_cs,
    output        [ 1:0] nvram_we,
    input         [15:0] nvram_dout,
    // Video interface
    output reg           pal_cs, vflag_cs, vctrl_cs, // same as in jtkiwi
    input         [15:0] pal_dout,

    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,

    // Cabinet
    input         [ 5:0] joystick1,
    input         [ 5:0] joystick2,
    input         [ 1:0] cab_1p,
    input         [ 1:0] coin,
    input                service,
    input         [15:0] dipsw,
    input                dip_pause,
    input                dip_test,
    input                tilt,
    output        [ 7:0] st_dout,
    input         [ 7:0] debug_bus
);
`ifndef NOMAIN
wire [23:1] A;
wire [ 2:0] FC;
reg  [15:0] cab_dout, cpu_din;
reg  [ 9:0] cab2_dout;
reg  [ 2:0] IPLn;
wire        int4ms, int16ms,
            cpu_cen, cpu_cenb, dtackn, VPAn, HALTn,
            UDSn, LDSn, RnW, ASn, BUSn, bus_busy, bus_cs;
reg         ipl2_cs, ipl1_cs, nvram_cs, dips_cs, tlc_cs, tlv_cs,
            cab_cs, snd_cs, ram_cs;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign cpu_addr = A[13:1];
assign rom_addr = A[19:1];
assign VPAn     = ~&{A[23],~ASn};
assign ram_dsn  = {UDSn, LDSn};
assign ram_we   = ~RnW;
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | (ram_cs & ~ram_ok);
assign BUSn     = ASn | (LDSn & UDSn);
assign cpu_rnw  = RnW;
assign nvram_we = ~ram_dsn & {2{nvram_cs&~RnW}};

always @* begin
    rom_cs   = !BUSn &&  A[23:20]==0;
    ipl2_cs  = !ASn  &&  A[23:20]==1;
    nvram_cs = !BUSn &&  A[23:19]==2;
    ipl1_cs  = !ASn  &&  A[23:20]==3;
//  wdog_cs  = !ASn  &&  A[23:20]==4;
    dips_cs  = !ASn  &&  A[23:20]==6;
    pal_cs   = !ASn  &&  A[23:20]==7;
    tlc_cs   = !ASn  &&  A[23:20]==8;  // tiles configuration
    tlv_cs   = !ASn  &&  A[23:20]==9;  // tiles VRAM
    cab_cs   = !ASn  &&  A[23:20]==10;
    snd_cs   = !ASn  &&  A[23:20]==11;
    // SETA X1-001 chip
    vflag_cs = !ASn  &&  A[23:20]==12;
    vctrl_cs = !ASn  &&  A[23:20]==13;
    vram_cs  = !ASn  &&  A[23:20]==14;

    ram_cs   = !ASn  &&  A[23:20]==15;
end

always @* begin
    IPLn = 7;
    if( int16ms ) IPLn[1] = 0;
    if( int4ms  ) IPLn[2] = 0;
end

always @(posedge clk) begin
    HALTn    <= dip_pause & ~rst;
    case(A[4:1])
        0: cab_dout <= {8'd0,cab_1p[0], 1'b1, joystick1};
        1: cab_dout <= {8'd0,cab_1p[1], 1'b1, joystick2};
        4: cab_dout <= {8'd0,coin[0],coin[1],service,tilt,4'hf};
        // 8: rotation
    endcase
    cpu_din  <= rom_cs   ? rom_data   :
                ram_cs   ? ram_dout   :
                nvram_cs ? nvram_dout :
                snd_cs   ? snd_rply   :
                dips_cs  ? dipsw      :
                cab_cs   ? cab_dout   : 16'h0;
end

/* verilator tracing_off */
jtframe_edge u_lvbl(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof (~lvbl      ),
    .clr    ( ipl1_cs   ),
    .q      ( int16ms   )
);

jtframe_edge u_lvbl(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( cen244    ),
    .clr    ( ipl2_cs   ),
    .q      ( int4ms    )
);

jtframe_8bit_reg u_snd(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( RnW       ),
    .din        ( cpu_dout[7:0] ),
    .cs         ( snd_cs    ),
    .dout       ( snd_cmd   )
);

jtframe_16bit_reg u_sys2(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( RnW       ),
    .dsn        ( ram_dsn   ),
    .din        ( cpu_dout  ),
    .cs         ( sys2_cs   ),
    .dout       ( sys2_dout )
);

jtframe_68kdtack_cen #(.W(6),.RECOVERY(1)) u_bus_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 5'd1      ),  // numerator
    .den        ( 6'd6      ),  // denominator, 6 (48/6=8MHz)
    .DTACKn     ( dtackn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    // Frequency report
    .fave       (           ),
    .fworst     (           )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

    // Buses
    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),


    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),

    .BERRn      ( 1'b1        ),
    // Bus arbitrion
    .HALTn      ( HALTn       ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( dtackn      ),
    .IPLn       ( IPLn        ) // VBLANK
);
`else
    initial begin
        ram_cs    = 0;
        rom_cs    = 0;
    end
`endif
endmodule
