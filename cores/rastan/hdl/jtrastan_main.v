/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-4-2022 */

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
    input                opwolf,
    input                rbisland,
    input                cchip,

    output reg           cchip_cs,
    input         [ 7:0] cchip_dout,

    input         [ 8:0] gun_xoffs,
    input         [ 8:0] gun_yoffs,

    output               cpu_cen,
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

    output        [ 2:0] obj_pal,
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
    input         [ 8:0] gun_x,
    input         [ 8:0] gun_y,
    input         [ 1:0] cab_1p,
    input         [ 1:0] coin,
    input                service,
    input                tilt,
    input                dip_test,
    input                dip_pause,
    input         [ 7:0] dipsw_a,
    input         [ 7:0] dipsw_b
);
reg out_cs;
`ifndef NOMAIN
wire [23:1] A;
wire        cpu_cenb;
wire        UDSn, LDSn, RnW, allFC, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
reg         io_cs, otport1_cs, inport_cs, dip_cs, gun_cs;
reg  [ 7:0] cab_dout;
reg  [15:0] cpu_din;
wire        ok_dly;
reg  [ 8:0] opwolf_gun_x, opwolf_gun_y;
wire [15:0] cpu_dout;
reg         intn, LVBLl;
wire        bus_cs, bus_busy, bus_legit;

assign main_addr= A[18:1];
assign main_dsn = {UDSn, LDSn};
assign main_rnw = RnW;
assign main_dout= cpu_dout;
assign allFC    = ~&FC; // allFC is high if the CPU is not accessing the "CPU space"
// Rastan/Op Wolf take the video IRQ on level 5; Rainbow Islands on level 4.
assign IPLn     = { intn, 1'b1, rbisland ? 1'b1 : intn };
// Autovector the video IRQ during its IACK cycle: level 5 for Rastan/Op Wolf,
// level 4 for Rainbow Islands (A[3:1] carries the acknowledged level).
assign VPAn     = !(!ASn && FC==7 && A[3:1]==(rbisland ? 3'd4 : 3'd5) && RnW);
assign bus_cs   = rom_cs | vram_cs | ram_cs;
wire [1:0] ok_cs, ok_in;
assign ok_cs = { rom_cs, vram_cs | ram_cs };
assign ok_in = { rom_ok, ram_ok };
assign bus_busy = (rom_cs | vram_cs | ram_cs) & ~ok_dly;
assign bus_legit= vram_cs & ~sdakn;
// Light-gun offsets come from the header (gun_xoffs/gun_yoffs inputs), derived
// per set at MRA build time from the same ROM bytes MAME's init_opwolf reads.
// Registered (adder out of the read path); the gun value is quasi-static so the
// 1-cycle latency is harmless.
always @(posedge clk) begin
    opwolf_gun_x <= gun_x + gun_xoffs;
    opwolf_gun_y <= gun_y + gun_yoffs;
end

always @* begin
    rom_cs  = allFC && (opwolf ? A[23:18]==0 : rbisland ? A[23:19]==0 : A[23:17]<3) && !ASn;
    vram_cs = allFC && A[23:19]==5'h18 && !ASn && {UDSn,LDSn}!=3;
    ram_cs  = allFC && (opwolf ? A[23:15]==9'h20 : A[23:18]==6'h4) &&
              !ASn && {UDSn,LDSn}!=3;
    obj_cs  = allFC && A[23:20]==4'hd && !ASn;
    io_cs   = allFC && A[23:20]==4'h3 && !ASn;
    pal_cs  = allFC && A[23:18]==6'h8 && !ASn;
    sub_cs  = allFC && A[23:20]==4'h8 && !ASn && !rbisland;
    // Op Wolf C-chip at 0x0f0000; Rainbow Islands C-chip at 0x800000
    cchip_cs= cchip && allFC && (opwolf ? A[23:16]==8'h0f : A[23:20]==4'h8) && !ASn;
    // Video control registers are not written to SDRAM
    if( vram_cs && A[18:16]!=0 ) begin
        scr_cs  = 1;
        vram_cs = 0;
    end else begin
        scr_cs  = 0;
    end


    out_cs     = 0;
    otport1_cs = 0;
    sn_we      = 0;
    sn_rd      = 0;
    inport_cs  = 0;
    dip_cs     = 0;
    gun_cs     = 0;
    if( opwolf && io_cs ) begin
        out_cs = !RnW && A[19:17]==3'b100;
        dip_cs =  RnW && A[19:17]==3'b100;
        gun_cs =  RnW && A[19:17]==3'b101;
        sn_we  = !RnW && !UDSn && A[19:17]==3'b111;
        sn_rd  =  RnW && !UDSn && A[19:17]==3'b111 && A[1];
    end else if( rbisland && io_cs ) begin
        // 3a0000 sprite ctrl, 390000/3b0000 DSWA/DSWB, 3e0001/3 sound (PC060HA)
        out_cs = !RnW && A[19:16]==4'ha;
        dip_cs =  RnW && (A[19:16]==4'h9 || A[19:16]==4'hb);
        sn_we  = !RnW && !LDSn && A[19:16]==4'he;
        sn_rd  =  RnW && !LDSn && A[19:16]==4'he && A[1];
    end else if( io_cs && !LDSn && A[19] ) begin
        case( {RnW, A[18:17]} )
            0: out_cs     = 1;
            1: otport1_cs = 1;
            //2: wdog_cs    = 1;
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
               cchip_cs  ? {8'hff, cchip_dout} :
               dip_cs    ? {8'hff, (rbisland ? A[17] : A[1]) ? dipsw_b : dipsw_a} :
               gun_cs    ? (cchip ? (A[1] ? {7'h7f, opwolf_gun_y} :
                                            {7'h7f, opwolf_gun_x}) :
                                    (A[1] ? {5'd0, ~coin[1:0], opwolf_gun_y} :
                                      {2'd0, cab_1p[0], tilt, service,
                                       joystick1[5], joystick1[4], opwolf_gun_x})) :
               inport_cs ? { 8'hff, cab_dout }  :
	               sn_rd     ? (opwolf ? {4'hf, sn_dout, 8'hff} : {12'hfff, sn_dout}) :
	               16'hffff;
end

jtframe_okdly #(.W(2)) u_okdly(
    .rst    ( rst    ),
    .clk    ( clk    ),
    .cs     ( ok_cs  ),
    .ok     ( ok_in  ),
    .ok_dly ( ok_dly )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        LVBLl <= 0;
    end else begin
        LVBLl <= LVBL;
        if( !VPAn )
            intn <= 1;
        else if( !LVBL && LVBLl && dip_pause)
            intn <= 0;
    end
end


function [5:0] mapjoy( input [5:0] j );
    mapjoy = { j[5:4], j[0], j[1], j[2], j[3] };
endfunction


always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mintn    <= 0;
        snd_rstn <= 0;
        cab_dout <= 0;
    end else begin
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

jtframe_68kdtack_cen #(.W(12)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( bus_legit ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    // Same divider chain as the Z80: on the board both CPUs come off the one
    // 16MHz XTAL, exactly 2:1.
    // This runs on clk48 and the z80 runs on clk24
    .num        ( 11'd231   ),
    .den        ( 12'd1541  ),
    .DTACKn     ( DTACKn    ),
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
    .HALTn      ( 1'b1        ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        ) // VBLANK
);
`else
assign main_addr=0, main_dsn=0, main_dout=0, main_rnw=0, cpu_cen=0;
initial begin
    rom_cs   = 0;
    ram_cs   = 0;
    vram_cs  = 0;
    scr_cs   = 0;
    pal_cs   = 0;
    obj_cs   = 0;
    out_cs   = 0;
    sn_we    = 0;
    sn_rd    = 0;
    sub_cs   = 0;
    cchip_cs = 0;
    snd_rstn = 0;
    mintn    = 0;
end
`endif

wire [4:0] nc;
wire [7:0] out_cfg;
assign obj_pal = out_cfg[7:5];

jtframe_8bit_reg #(
    .SIMFILE( "rest.bin" ),
    .OFFSET ( 32         )
) u_obj_pal(
    .rst    ( rst            ),
    .clk    ( clk            ),
    .wr_n   ( main_rnw       ),
    .din    ( main_dout[7:0] ),
    .cs     ( out_cs         ),
    .dout   ( out_cfg        )
);

endmodule
