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
    Date: 8-2026 */

/*  Address decode, from the Superman schematic (W5100307A) sheet 2.

    Two F138 3-to-8 decoders take A22,A21,A20 on C/B/A. #17 is gated by
    A23 high and produces the upper map; #18 covers the low half:

      A23=1, A[22:20]                    A23=0, A[22:20]
        0  800000  SOUND CS  TC0140SYT     0  000000  ROM (A[22:19]==0)
        1  900000  TC0030CMD CS            3  300000  watchdog-ish, write only
        3  b00000  CLRAM CS   palette      4  400000  idem
        4  c00000  VDCS CS    unused       5  500000  DSW read
        5  d00000  VDCM CS    X1-002       6  600000  idem
        6  e00000  ORAM CS    X1-001
        7  f00000  WRAM CS    work RAM

    Partial decode: the chips only see A23 and A[22:20], so every region
    mirrors through its whole 1 MB slot exactly as on the PCB.

    The X1-001/X1-002 CPU side (ORAM, spriteylow, spritectrl) is owned by
    the video module, so only the selects leave here.    */

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
    output               rom_cs,
    output        [18:1] rom_addr,
    input         [15:0] rom_data,
    input                rom_ok,

    // work RAM and palette (BRAM, see cfg/mem.yaml)
    output        [ 1:0] ram_we,
    input         [15:0] ram_dout,
    output        [ 1:0] pal_we,
    input         [15:0] pal_dout,

    // X1-001 / X1-002, owned by jttaitox_video
    output               oram_cs,    // e00000 ORAM CS
    output               vdcm_cs,    // d00000 VDCM CS
    input         [15:0] vid_dout,

    // TC0140SYT
    output               syt_cs,
    input         [ 3:0] syt_dout,

    // TC0030CMD
    output               cchip_cs,
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

wire        vma;            // valid memory access: not CPU space, AS asserted
wire        a23;
wire [ 2:0] region;
wire        ram_cs, pal_cs, dsw_cs, in_cs;

`ifndef NOMAIN
wire [23:1] A;
wire        cpu_cenb;
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
wire [15:0] cpu_din_w;
reg  [15:0] cpu_din;
reg  [ 7:0] cab_dout;
reg         intn, LVBLl;
wire        bus_cs, bus_busy;
wire        dws;            // any data strobe

assign cpu_addr = A;
assign rom_addr = A[18:1];
assign cpu_dsn  = { UDSn, LDSn };
assign cpu_rnw  = RnW;
assign vma      = ~&FC && !ASn;
assign a23      = A[23];
assign region   = A[22:20];
assign dws      = {UDSn,LDSn}!=3;

// F138 #17 - A23 high
// Qualified by LDS: the comm chip advances its pointer on cs edges, so an
// address-strobe-only select gives it spurious ones - including from the
// 800000 read the driver maps as nopr.
assign syt_cs   = vma &&  a23 && region==3'd0 && !LDSn;
assign cchip_cs = vma &&  a23 && region==3'd1 && p039a;
assign pal_cs   = vma &&  a23 && region==3'd3;
assign vdcm_cs  = vma &&  a23 && region==3'd5;
assign oram_cs  = vma &&  a23 && region==3'd6;
assign ram_cs   = vma &&  a23 && region==3'd7;
// F138 #18 - A23 low
assign rom_cs   = vma && !a23 && A[22:19]==4'd0;
assign dsw_cs   = vma && !a23 && region==3'd5;
// Without a C-chip the same slot is the direct input port
assign in_cs    = vma &&  a23 && region==3'd1 && !p039a;

assign ram_we   = {2{ram_cs & ~RnW}} & ~{UDSn,LDSn};
assign pal_we   = {2{pal_cs & ~RnW}} & ~{UDSn,LDSn};

// The C-chip games take the VBL interrupt on level 6, the rest on level 2
assign IPLn     = intn ? 3'b111 : (p039a ? 3'b001 : 3'b101);
assign VPAn     = !(!ASn && FC==7 && A[3:1]==(p039a ? 3'd6 : 3'd2) && RnW);

assign bus_cs   = rom_cs;
assign bus_busy = rom_cs & ~rom_ok;

assign cpu_din_w= rom_cs   ? rom_data  :
                  ram_cs   ? ram_dout  :
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


always @(posedge clk, posedge rst) begin
    if( rst ) begin
        intn  <= 1;
        LVBLl <= 0;
    end else begin
        LVBLl <= LVBL;
        if( !VPAn )
            intn <= 1;
        else if( !LVBL && LVBLl && dip_pause )
            intn <= 0;
    end
end

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
       rom_cs=0, rom_addr=0, ram_we=0, pal_we=0,
       oram_cs=0, vdcm_cs=0, syt_cs=0, cchip_cs=0,
       vma=0, a23=0, region=0, ram_cs=0, pal_cs=0, dsw_cs=0, in_cs=0;
`endif

endmodule
