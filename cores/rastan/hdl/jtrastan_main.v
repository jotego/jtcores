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
    Date: 3-4-2022 */

/* PAL equations

/o12 = i1 & /i2 & /i3 & /i4 & /i5 & /i6 & /i7 & /i8 & /i11
/ROM0 = ~&FC & A[23:17]==000'0000 & ~AS

/o13 = i1 & /i2 & /i3 & /i4 & /i5 & /i6 & /i7 & i8 & /i11
/ROM1 = ~&FC & A[23:17]==000'0001 & ~AS

/o14 = i1 & /i2 & /i3 & /i4 & /i5 & /i6 & i7 & /i8 & /i11
/ROM2 = ~&FC & A[23:17]==000'0010 & ~AS

/o15 = i1 & i2 & i3 & /i4 & /i5 & /i11
/scn = ~&FC & A[23:20]=='b1100 & ~AS

/o16 = i1 & i2 & i3 & /i4 & i5 & /i11
/obj = ~&FC & A[23:20]=='b1101 & ~AS

/o17 = i1 & /i2 & /i3 & i4 & i5 & /i11
/io  = ~&FC & A[23:20]=='b0011 & ~ASn

/o18 = i1 & /i2 & /i3 & /i11
/dtackn = ~&FC & A[23:22]==0 & ~ASn - Dtack for non video access

/o19 = i1 & i2 & /i3 & /i4 & /i5 & /i11
/ext = &~FC & A[23:22]=='b1001 & ~ASn - seems to be a test port

From Taito-B04-10.jed

/o15 = /i1 & /i2 & i3 & /i4 & /i5 & /i6 & /i7 & /i8 & /i9 & i13
/CLWE = A[23:18]=='b001000 && ~LDS && ~UDS && ~RnW & ~&FC

/o16 = /i1 & /i2 & i3 & /i4 & /i5 & /i6 & /i11 & i13
/CLCS = A[23:18]=='b001000 & ~ASn & ~&FC

/o17 = /i1 & /i2 & /i3 & i4 & /i5 & /i6 & /i8 & /i11 & i13
/WURAM = A[23:18]=='b000100 & ~AS & ~UDS & ~&FC

/o18 = /i1 & /i2 & /i3 & i4 & /i5 & /i6 & /i7 & /i11 & i13
/WLRAM = A[23:18]=='b000100 & ~AS & ~LDS & ~&FC

/o19 = i1 & /i2 & /i3 & /i4 & /i11 & i13
/SUBCS = A[23:20]=='b1000 & ~LDS & ~&FC

From Taito-B04-11.jed

/o14 = /i1 & i2 & /i3 & i4 & /i5 & i6
/irq_clear = &FC & RnW & ~AS & A[3:1]=='b101

/o16 = /i1 & i2 & /i3 & i4 & /i5 & i6
/vpa = &FC & RnW & ~AS & A[3:1]=='b101

/o17 = /i8
/ipl2 = ~irqn

/o19 = /i8
/ipl0 = ~irqn

Note that /i9 (subint) is not connected


*/

module jtrastan_main(
    input                rst,
    input                clk, // 48 MHz
    input                LVBL,

    output        [18:1] main_addr,
    output        [ 1:0] main_dsn,
    output        [15:0] main_dout,
    output               main_rnw,
    output reg           rom_cs,
    output reg           ram_cs,
    output reg           vram_cs,
    output reg           scr_cs,
    output reg           pal_cs,
    output reg           obj_cs,

    output reg    [ 2:0] obj_pal,
    input         [15:0] oram_dout,
    input         [15:0] pal_dout,
    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,

    input                odakn,
    input                sdakn,

    // Sound interface
    input         [ 3:0] sn_dout,
    output reg           sn_we,
    output reg           sn_rd,

    // This interface shown in the
    // sch. seems to go to a test board
    output reg           sub_cs,
    output reg           snd_rstn,
    output reg           mintn,

    input         [ 5:0] joystick1,
    input         [ 5:0] joystick2,
    input         [ 1:0] cab_1p,
    input         [ 1:0] coin,
    input                service,
    input                tilt,
    input                dip_test,
    input                dip_pause,
    input         [ 7:0] dipsw_a,
    input         [ 7:0] dipsw_b
);

wire [23:1] A;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, allFC, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
reg         io_cs, out_cs, otport1_cs,
            wdog_cs, inport_cs;
reg  [ 7:0] cab_dout;
reg  [15:0] cpu_din;
wire [15:0] cpu_dout;
reg         intn, LVBLl;
wire        bus_cs, bus_busy, bus_legit;

assign main_addr= A[18:1];
assign main_dsn = {UDSn, LDSn};
assign main_rnw = RnW;
assign main_dout= cpu_dout;
assign allFC    = ~&FC; // allFC is high if the CPU is not accessing the "CPU space"
assign IPLn     = { intn, 1'b1, intn };
assign VPAn     = !(!ASn && FC==7 && A[3:1]==5 && RnW);
assign bus_cs   = rom_cs | vram_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | ( (vram_cs | ram_cs) & ~ram_ok);
assign bus_legit= vram_cs & ~sdakn;


always @* begin
    rom_cs  = allFC && A[23:17]<3 && !ASn;
    vram_cs = allFC && A[23:19]==5'h18 && !ASn && {UDSn,LDSn}!=3;
    ram_cs  = allFC && A[23:18]==6'h4  && !ASn && {UDSn,LDSn}!=3;
    obj_cs  = allFC && A[23:20]==4'hd && !ASn;
    io_cs   = allFC && A[23:20]==4'h3 && !ASn;
    pal_cs  = allFC && A[23:18]==6'h8 && !ASn;
    sub_cs  = allFC && A[23:20]==4'h8 && !ASn;
    // Video control registers are not written to SDRAM
    if( vram_cs && A[18:16]!=0 ) begin
        scr_cs  = 1;
        vram_cs = 0;
    end else begin
        scr_cs  = 0;
    end


    out_cs     = 0;
    otport1_cs = 0;
    wdog_cs    = 0;
    sn_we      = 0;
    sn_rd      = 0;
    inport_cs  = 0;
    if( io_cs && !LDSn && A[19] ) begin
        case( {RnW, A[18:17]} )
            0: out_cs     = 1;
            1: otport1_cs = 1;
            2: wdog_cs    = 1;
            3: sn_we      = 1;
            4: inport_cs  = 1;
            7: sn_rd      = 1;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    cpu_din <= rom_cs    ? rom_data :
               ( ram_cs | vram_cs ) ? ram_dout :
               obj_cs    ? oram_dout :
               pal_cs    ? pal_dout  :
               inport_cs ? { 8'hff, cab_dout }  :
               sn_rd     ? { 12'hfff, sn_dout } :
               16'hffff;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        LVBLl <= 0;
    end else begin
        LVBLl <= LVBL;
        if( !VPAn )
            intn <= 1;
        else if( !LVBL && LVBLl )
            intn <= 0;
    end
end

function [5:0] mapjoy( input [5:0] j );
    mapjoy = { j[5:4], j[0], j[1], j[2], j[3] };
endfunction


always @(posedge clk, posedge rst) begin
    if( rst ) begin
        obj_pal  <= 0;
        mintn    <= 0;
        snd_rstn <= 0;
        cab_dout <= 0;
    end else begin
        if( out_cs ) obj_pal <= cpu_dout[7:5]; // coin counters here too
        if( otport1_cs ) { mintn, snd_rstn } <= cpu_dout[1:0];
        case( A[3:1] )
            0: cab_dout <= { 2'b11, mapjoy(joystick1) };
            1: cab_dout <= { 2'b11, mapjoy(joystick2) };
            2: cab_dout <= 8'hbf; // "SPECIAL"
            3: cab_dout <= {1'b1, coin, cab_1p,
                    tilt, dip_test, service };
            4: cab_dout <= dipsw_a;
            5: cab_dout <= dipsw_b;
            default:;
        endcase
    end
end

jtframe_68kdtack_cen #(.W(8)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( bus_legit ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 7'd1      ),  // numerator
    .den        ( 8'd6      ),  // denominator
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    // Frequency report
    .fave       (           ),
    .fworst     (           ),
    .frst       (           )
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
    .HALTn      ( dip_pause   ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        ) // VBLANK
);

endmodule
