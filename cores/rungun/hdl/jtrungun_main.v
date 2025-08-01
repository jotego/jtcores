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
    Date: 4-7-2025 */

module jtrungun_main(
    input                rst, clk, pxl_cen,
    input                lvbl,
    input                disp,

    output reg    [21:1] main_addr,
    output        [ 1:0] ram_dsn,
    output               ram_we,
    output        [15:0] cpu_dout,
    input         [ 7:0] vtimer_mmr,
    // 8-bit interface
    output               cpu_rnw,
    output        [ 1:0] cpal_we,  vmem_we,  lmem_we, pmem01_we,
    output               pmem2_we,
    output reg           ccu_cs, psreg_cs,

    output        [11:1] cpal_addr,
    output        [12:1] vmem_addr,
    output        [14:0] pmem_addr,

    output reg           rom_cs,
    output reg           ram_cs,

    input         [ 7:0] pmem2_dout,
    input         [15:0] pmem01_dout, vmem_dout, lmem_dout,
    input         [15:0] omem_dout,
    input         [15:0] cpal_dout,
    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,

    // video configuration
    output        [ 3:0] psac_bank,
    output               gvflip, ghflip,
    output               pri,
    output               lrsw,
    // Objects
    output           reg objrg_cs, objrm_cs,
    output               objcha_n,
    input                odma,
    // EEPROM
    output        [ 6:0] nv_addr,
    input         [ 7:0] nv_dout,
    output        [ 7:0] nv_din,
    output               nv_we,
    // Sound
    output               pair_we, sdon,
    input         [ 7:0] pair_dout,
    // Cabinet
    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input         [ 6:0] joystick3,
    input         [ 6:0] joystick4,
    input         [ 3:0] cab_1p,
    input         [ 3:0] coin,
    input         [ 3:0] service,
    input         [ 3:0] dipsw,
    input                dip_pause,
    input                dip_test,
    output        [ 7:0] st_dout,
    input         [ 7:0] debug_bus
);
`ifndef NOMAIN
wire [23:1] A;
wire [15:0] sys1_dout, sys2_dout;
reg  [15:0] cab_dout, cpu_din, cab1_dout;
reg  [ 9:0] cab2_dout;
wire [ 7:0] vmem_mux;
reg  [15:0] pmem_mux;
reg  [ 2:0] IPLn;
wire        cpu_cen, cpu_cenb, bus_dtackn, dtackn, VPAn,
            fmode, fsel, l5mas, l3mas, l2mas, int5, l_r,
            UDSn, LDSn, RnW, ASn, BUSn, bus_busy, bus_cs,
            eep_rdy, eep_do, eep_di, eep_clk, eep_cs;
reg         boot_cs, xrom_cs, gfx_cs, sys2_cs, sys1_cs, vmem_cs,
            io1_cs, io2_cs, io_cs, misc_cs, cpal_cs, cab_cs, HALTn,
            pslrm_cs, psvrm_cs,
            objch_cs, pair_cs, sdon_cs, psch_cs, rom_good, ram_good;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign VPAn     = ~&{A[23],~ASn};
assign ram_dsn  = {UDSn, LDSn};
assign ram_we   = ~RnW;
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~(rom_ok & rom_good)) | (ram_cs & ~(ram_ok & ram_good));
assign BUSn     = ASn | (LDSn & UDSn);
assign cpu_rnw  = RnW;
// sys1
assign pri      = sys1_dout[14];
assign l5mas    = sys1_dout[10];
// assign l2mas =~sys1_dout[ 8];
assign l_r      = sys1_dout[ 7];
assign gvflip   = sys1_dout[ 6];
assign ghflip   = sys1_dout[ 5];
assign eep_di   = sys1_dout[ 0];
assign eep_clk  = sys1_dout[ 2];
assign eep_cs   = sys1_dout[ 1];
// sys2
// assign l3mas = sys2_dout[ 8];
assign psac_bank= sys2_dout[7:4];
assign fmode    = sys2_dout[ 1];
assign fsel     = sys2_dout[ 0];
assign st_dout  = 0;
assign objcha_n = ~objch_cs;

assign cpal_we   = ~ram_dsn & {2{ cpal_cs  & ~RnW}};
assign lmem_we   = ~ram_dsn & {2{ pslrm_cs & ~RnW}};
assign pmem01_we = ~ram_dsn & {2{psvrm_cs & ~RnW &  A[1]}};
assign pmem2_we  = ~LDSn    & psvrm_cs & ~RnW & ~A[1];
assign vmem_we   = {2{vmem_cs & ~RnW & ~LDSn}} & {~A[1],A[1]};
assign vmem_mux  = A[1] ? vmem_dout[7:0] : vmem_dout[15:8];
// MSB could either be L-R or SEL signals (see page 4-5B/5C)
// as they are changed at the same time during test
assign cpal_addr = { l_r, A[10:1] };
assign vmem_addr = { l_r, A[12:2] };
assign pmem_addr = { l_r, A[15:2] }; // A[17:16] are set to zero when psvrm_cs is set
assign pair_we   = pair_cs & ~RnW & ~UDSn;
assign sdon      = sdon_cs;

assign lrsw      = fmode ? disp : fsel;

always @* begin
    // 056541 PAL
    boot_cs =   !ASn  &&  A[23:20]==0 && RnW && !BUSn;
    xrom_cs =   !ASn  && (A[23:20]==2 || A[23:20]==1) && !BUSn;
    ram_cs  =   !ASn  &&  A[23:19]==5'b0011_1 && !BUSn;
    gfx_cs  =   !ASn  &&  A[23:21]==3'b011;     // $3?_???? ~$7?_????
    // dmac_cs =   !ASn  &&  A[23:19]==5'b0011_1;  // $38_???? same as RAM in PAL equations
    cpal_cs =   !ASn  &&  A[23:19]==5'b0011_0;
    misc_cs =   !ASn  &&  A[23:21]==3'b010; // $4?_...
    // 74F138 at 11T
    vmem_cs = gfx_cs  &&  A[20:18]==5; // $74_????
    pslrm_cs= gfx_cs  &&  A[20:18]==4; // $70_... 2k PSAC line
    psvrm_cs= gfx_cs  &&  A[20:18]==3; // $6C_... 32k+32k of RAM for PSAC
    psreg_cs= gfx_cs  &&  A[20:18]==2; // $68_
    objrg_cs= gfx_cs  &&  A[20:18]==1; // $64_... object registers
    objrm_cs= gfx_cs  &&  A[20:18]==0; // $60_... object RAM
    // 74F138 at 13P
    objch_cs= misc_cs &&  A[20:18]==7; // K055673 registers and ROM read
    pair_cs = misc_cs &&  A[20:18]==6;
    sdon_cs = misc_cs &&  A[20:18]==5;
    ccu_cs  = misc_cs &&  A[20:18]==3;
    io_cs   = misc_cs &&  A[20:18]==2;
    psch_cs = misc_cs &&  A[20:19]==0;

    sys2_cs = io_cs   &&  A[ 3: 2]==3;
    sys1_cs = io_cs   &&  A[ 3: 2]==2;
    io2_cs  = io_cs   &&  A[ 3: 2]==1;
    io1_cs  = io_cs   &&  A[ 3: 2]==0;

    cab_cs  = io1_cs  || io2_cs;
end

always @* begin
    rom_cs    = boot_cs | xrom_cs;
    main_addr = A[21:1];
    if(boot_cs) main_addr[21:20]=0;
    if(rom_cs ) case(A[21:20])
        1: main_addr[21:20] = 2'b10;
        2: main_addr[21:20] = 2'b01;
        default:;
    endcase
end

always @* begin
    IPLn = 7;
    if( int5 ) IPLn = ~3'd5;
    // 2 more interrupt sources seen on sch CPU sheet
end

always @(posedge clk) begin
    rom_good  <= rom_cs & rom_ok;
    ram_good  <= ram_cs & ram_ok;
    cab1_dout <= A[1] ? {cab_1p[3],joystick4,cab_1p[1],joystick2}:
                        {cab_1p[2],joystick3,cab_1p[0],joystick1};
    // odma=0 halts the game
    cab2_dout <= { lrsw, odma, A[1] ? {dipsw, dip_test, 1'b1, eep_rdy, eep_do }:
                                      {service,   coin}};
    cab_dout  <= io1_cs ? cab1_dout : {6'h0, cab2_dout};
    HALTn     <= dip_pause & ~rst;
    pmem_mux  <= A[1] ? pmem01_dout : {8'd0,pmem2_dout};
    cpu_din <= rom_cs   ? rom_data          :
               ram_cs   ? ram_dout          :
               cpal_cs  ? cpal_dout         :
               vmem_cs  ? {8'd0,vmem_mux}   :
               ccu_cs   ? {8'd0,vtimer_mmr} :
               objrm_cs ? omem_dout         :
               psvrm_cs ? pmem_mux          :
               pslrm_cs ? lmem_dout         :
               pair_cs  ? {pair_dout,8'd0}  :
               cab_cs   ? cab_dout          : 16'h0;
end

/* verilator tracing_off */
jtframe_edge u_lvbl(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( lvbl      ),
    .clr    (~l5mas     ),
    .q      ( int5      )
);

jtframe_16bit_reg u_sys1(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( RnW       ),
    .dsn        ( ram_dsn   ),
    .din        ( cpu_dout  ),
    .cs         ( sys1_cs   ),
    .dout       ( sys1_dout )
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

jt5911 #(.SIMFILE("nvram.bin")) u_eeprom(
    .rst        ( rst       ),
    .clk        ( clk       ),
    // chip interface
    .sclk       ( eep_clk   ),         // serial clock
    .sdi        ( eep_di    ),         // serial data in
    .sdo        ( eep_do    ),         // serial data out
    .rdy        ( eep_rdy   ),
    .scs        ( eep_cs    ),         // chip select, active high. Goes low in between instructions
    // Dump access
    .mem_addr   ( nv_addr   ),
    .mem_din    ( nv_din    ),
    .mem_we     ( nv_we     ),
    .mem_dout   ( nv_dout   ),
    // NVRAM contents changed
    .dump_clr   ( 1'b0      ),
    .dump_flag  (           )
);

jtrungun_dtack u_dtack(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .bus_dtackn ( bus_dtackn),
    .fix_cs     ( vmem_cs   ),
    .dsn        ( ram_dsn   ),
    .dtackn     ( dtackn    )
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
`ifdef JTFRAME_SDRAM96
    .den        ( 6'd6      ),  // denominator, 6 (16MHz)
`else
    .den        ( 6'd3      ),  // denominator, 3 (16MHz)
`endif
    .DTACKn     ( bus_dtackn),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    // Frequency report
    .fave       (           ),
    .fworst     (           )
);
/* verilator tracing_on */
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
    .FC         (             ),

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
    assign
        gvflip    = 0,
        ghflip    = 0,
        pri       = 0, lrsw = 1, vmem_addr = 0, cpal_addr = 0, psac_bank = 0,
        vmem_we   = 0, cpu_dout = 0, ccu_cs = 0, cpal_we = 0,
        ram_we    = 0, psreg_cs = 0,
        cpu_rnw   = 1,
        main_addr = 0,
        ram_dsn   = 0, objrm_cs = 0, sdon = 0, objrg_cs=0, objcha_n=1,
        st_dout   = 0, lmem_we = 0, pmem01_we = 0, pmem_addr = 0,
        nv_addr   = 0, nv_din  = 0, nv_we = 0, pmem2_we = 0, pair_we=0;
`endif
endmodule
