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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
            Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-8-2026 */

module jttaitox_main(
    input                rst,
    input                clk,        // 48 MHz
    input                LVBL,

    // Board type from the MRA header. P0-039A is the only board with a
    // C-chip, and it is also the only one whose class installs the level-6
    // ISR, so "reads inputs directly at 900000" and "VBL on level 2" are
    // both just ~p039a and need no bits of their own.
    input                p039a,

    output               cpu_cen,
    output        [23:1] cpu_addr,
    output        [15:0] cpu_dout,
    output               cpu_rnw,
    output        [ 1:0] cpu_dsn,

    // 68k program ROM (SDRAM bank 0)
    output reg           rom_cs,
    output        [18:1] rom_addr,
    input         [15:0] rom_data,
    input                rom_ok,

    // work RAM lives in SDRAM bank 0, palette in BRAM (see cfg/mem.yaml)
    output reg           ram_cs,
    output        [13:1] ram_addr,
    input         [15:0] ram_data,
    output               ram_we,
    output        [ 1:0] ram_dsn,
    input                ram_ok,
    output        [ 1:0] pal_we,
    input         [15:0] pal_dout,

    // X1-001 / X1-002, owned by jttaitox_video
    output reg           oram_cs,    // e00000 ORAM CS
    output reg           vdcm_cs,    // d00000 VDCM CS
    input         [15:0] vid_dout,

    // TC0140SYT
    output reg           syt_cs,
    input         [ 3:0] syt_dout,

    // TC0030CMD
    output reg           cchip_cs,
    input         [ 7:0] cchip_dout,


    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input         [ 1:0] start_button,
    input         [ 1:0] coin,
    input                service,
    input                tilt,
    input                dip_pause,
    input         [ 7:0] dipsw_a,
    input         [ 7:0] dipsw_b
);

reg         pal_cs, dsw_cs, in_cs;

`ifndef NOMAIN
wire [23:1] A;
wire        cpu_cenb;
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
wire [15:0] cpu_din_w;
reg  [15:0] cpu_din;
reg  [ 7:0] cab_dout;
wire        intn;
wire        bus_cs, bus_busy, ok_dly;

assign cpu_addr = A;
assign rom_addr = A[18:1];
assign cpu_dsn  = { UDSn, LDSn };
assign cpu_rnw  = RnW;
// Two F138s take A22,A21,A20 on C/B/A; A23 picks which one (schematic
// sheet 2). Partial decode: each region mirrors through its 1 MB slot.
always @* begin
    syt_cs   = 0;
    cchip_cs = 0;
    in_cs    = 0;
    pal_cs   = 0;
    vdcm_cs  = 0;
    oram_cs  = 0;
    ram_cs   = 0;
    rom_cs   = 0;
    dsw_cs   = 0;
    if( !ASn && {UDSn,LDSn}!=2'b11 && ~&FC ) begin
        // F138 #17 - A23 high
        syt_cs   =  A[23] && A[22:20]==0;
        cchip_cs =  A[23] && A[22:20]==1 &&  p039a;
        in_cs    =  A[23] && A[22:20]==1 && !p039a;  // no C-chip: direct input port
        pal_cs   =  A[23] && A[22:20]==3;
        vdcm_cs  =  A[23] && A[22:20]==5;
        oram_cs  =  A[23] && A[22:20]==6;
        ram_cs   =  A[23] && A[22:20]==7;
        // F138 #18 - A23 low
        rom_cs   = !A[23] && A[22:19]==0;
        dsw_cs   = !A[23] && A[22:20]==5;
    end
end

assign ram_addr = A[13:1];
assign ram_we   = ram_cs & ~RnW;
assign ram_dsn  = { UDSn, LDSn };
assign pal_we   = {2{pal_cs & ~RnW}} & ~{UDSn,LDSn};

// The C-chip games take the VBL interrupt on level 6, the rest on level 2
assign IPLn     = intn ? 3'b111 : (p039a ? 3'b001 : 3'b101);
assign VPAn     = !(!ASn && FC==7 && A[3:1]==(p039a ? 3'd6 : 3'd2) && RnW);

// Both SDRAM buses stall the CPU through DTACK. jtframe_okdly holds the
// busy flag until the slot has answered for the current address.
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs | ram_cs) & ~ok_dly;

assign cpu_din_w= rom_cs   ? rom_data  :
                  ram_cs   ? ram_data  :
                  pal_cs   ? pal_dout  :
                  (oram_cs | vdcm_cs) ? vid_dout :
                  cchip_cs ? { 8'hff, cchip_dout } :
                  // dsw_input_r splits each DIP byte into two nibbles,
                  // selected by A[2:1]: 0/1 = DSWA lo/hi, 2/3 = DSWB lo/hi
                  dsw_cs   ? { 12'hfff, A[2] ? (A[1] ? dipsw_b[7:4] : dipsw_b[3:0])
                                             : (A[1] ? dipsw_a[7:4] : dipsw_a[3:0]) } :
                  in_cs    ? { 8'hff, cab_dout } :
                  syt_cs   ? { 12'hfff, syt_dout } :
                  16'hffff;

always @(posedge clk) cpu_din <= cpu_din_w;

// input_r on the cousins: three ports selected by A[2:1]
always @(posedge clk) begin
    case( A[2:1] )
        0: cab_dout <= { start_button[0], joystick1[6:4], joystick1[3:0] };
        1: cab_dout <= { start_button[1], joystick2[6:4], joystick2[3:0] };
        2: cab_dout <= { tilt, 4'hf, service, coin[1], coin[0] };
        default: cab_dout <= 8'hff;
    endcase
end

jtframe_edge #(.QSET(0)) u_int(
    .rst    ( rst               ),
    .clk    ( clk               ),
    .edgeof ( ~LVBL & dip_pause ),
    .clr    ( ~VPAn             ),
    .q      ( intn              )
);

`ifdef SIMULATION
// 68000 program-fetch dumper. The stream is a superset of MAME's PC list
// because the prefetch also fetches extension words.
integer main_tr; reg asn_q, prog_cyc; reg [23:1] pc_l; reg [15:0] op_l;
wire prog_rd = FC[1] & ~FC[0] & RnW;
initial main_tr = $fopen("taitox_main_fpga.tr","w");
always @(posedge clk) begin
    asn_q <= ASn;
    if(!ASn && prog_rd) begin prog_cyc<=1; pc_l<=A; op_l<=cpu_din_w; end
    if(!asn_q && ASn) begin
        if(prog_cyc && main_tr!=0) $fwrite(main_tr,"%06X: %04X\n",{pc_l,1'b0},op_l);
        prog_cyc<=0;
    end
end
final if(main_tr!=0) $fclose(main_tr);
`endif


jtframe_okdly #(.W(2)) u_okdly(
    .rst    ( rst              ),
    .clk    ( clk              ),
    .cs     ( { rom_cs, ram_cs } ),
    .ok     ( { rom_ok, ram_ok } ),
    .ok_dly ( ok_dly           )
);

jtframe_68kdtack_cen #(.W(8)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    // 16 MHz XTAL / 2 = 8 MHz, exactly 48/6
    .num        ( 7'd1      ),
    .den        ( 8'd6      ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

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
    .HALTn      ( 1'b1        ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        )
);
`else
assign cpu_addr=0, cpu_dout=0, cpu_rnw=1, cpu_dsn=3, cpu_cen=0,
       rom_addr=0, ram_addr=0, ram_we=0, ram_dsn=3, pal_we=0;
initial begin
    rom_cs=0; oram_cs=0; vdcm_cs=0; syt_cs=0; cchip_cs=0;
    ram_cs=0; pal_cs=0; dsw_cs=0; in_cs=0;
end
`endif

endmodule
