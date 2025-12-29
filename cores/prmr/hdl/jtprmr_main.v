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
    Date: 20-12-2025 */

module jtprmr_main(
    input                rst,
    input                clk, // 48 MHz
    input                LVBL,
    input                cpu_n,       // low when CPU can access video RAM

    output        [19:1] main_addr,
    output        [15:0] cpu_dout,
    output        [ 1:0] ram_dsn, lmem_we,
    // 8-bit interface
    output               cpu_we,
    output reg           pal_cs,
    output reg           pcu_cs,
    output reg           psreg_cs, psac_bank,
    // Sound interface
    input         [ 7:0] pair_dout,  // K053260 (PCM sound)
    output reg           sndon,     // irq trigger
    output               pair_we,

    output reg           rom_cs,
    output reg           ram_cs,
    output reg           vram_cs,
    output reg           obj_cs,

    input         [15:0] oram_dout,
    input         [15:0] lmem_dout,
    input         [ 7:0] vram_dout,
    input         [15:0] pal_dout,
    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,
    input                vdtac,
    input                tile_irqn,

    // video configuration
    output reg  [ 1:0]   objset_cs,
    output reg           rmrd, obank, zrmck,
    // EEPROM
    output      [ 6:0]   nv_addr,
    input       [ 7:0]   nv_dout,
    output      [ 7:0]   nv_din,
    output               nv_we,
    // Cabinet
    input         [ 6:0] joystick1, joystick2,
    input         [19:0] dipsw,
    input         [ 1:0] cab_1p,
    input         [ 1:0] coin,
    input         [ 1:0] service,
    input                dip_pause,
    input                dip_test,
    output        [ 7:0] st_dout,
    input         [ 7:0] debug_bus
);
`ifndef NOMAIN
wire [23:1] A;
wire        cpu_cen, cpu_cenb, ASn,
            UDSn, LDSn, RnW, allFC, VPAn, DTACKn,
            UDWn, LDWn, dtac,
            eep_rdy, eep_do, bus_cs, bus_busy, BUSn;
wire [ 2:0] FC;
reg  [ 2:0] IPLn, riders_dim;
reg         cab_cs, HALTn, pair_cs,
            eep_di, eep_clk, eep_cs, omsb_cs, pslrm_cs,
            psvrm_cs, eep_wr, cfg_wr;
reg  [15:0] cpu_din, cab_dout;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign main_addr= A[19:1];
assign ram_dsn  = {UDSn, LDSn};
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | (ram_cs & ~ram_ok);
assign BUSn     = ASn | &ram_dsn;
assign UDWn     = UDSn   | RnW;
assign LDWn     = LDSn   | RnW;

assign cpu_we   = ~RnW;
assign lmem_we  = ~ram_dsn & {2{ pslrm_cs & ~RnW}};

assign st_dout  = 0;
assign VPAn     = ~&{A[23],~ASn};
assign dtac     = DTACKn | ~vdtac;
assign pair_we  = pair_cs & ~RnW;

reg none_cs/*, wdog*/;

always @* begin
    rom_cs     = 0;
    ram_cs     = 0;
    pal_cs     = 0;
    cab_cs     = 0;
    vram_cs    = 0; // tilesys_cs
    obj_cs     = 0;
    objset_cs  = 0;
    sndon      = 0;
    pcu_cs     = 0;
    // 053936
    pslrm_cs   = 0;
    psreg_cs   = 0;
    psvrm_cs   = 0;
    // wdog    = 0;
    pair_cs    = 0;
    eep_wr     = 0;
    cfg_wr     = 0;
    if(!A[23]) casez(A[21:12]) // 2-4-4
       //   22 1111 1111
       //   10 9876 5432 - board references may be wrong
        10'b00_????_????: rom_cs  = 1;       // 00'0000 ~ 0F'FFFF - LS139 @ 3F
        10'b01_??00_00??: ram_cs  = ~BUSn;   // 10'0000 ~ 10'3FFF - LS138 @ 4G
        10'b01_??00_01??: obj_cs  = 1;       // 10'4000 ~ 10'7FFF
        10'b01_??00_10??: pal_cs  = 1;       // 10'8000 ~ 10'8FFF
        10'b01_??00_11??: pslrm_cs= 1;       // 10'C000 ~ 10'CFFF 053936 line RAM
        10'b01_??01_00??: objset_cs[0]=1;    // 11'0000 ~ 11'0FFF OBJSET0 - 053245
        10'b01_??01_01??: objset_cs[1]=~LDSn;// 11'4000 ~ 11'4FFF OBJSET1 - 053244
        10'b01_??01_10??: psreg_cs= 1;       // 11'8000 ~ 11'8FFF 053936 regs
        10'b01_??01_11??: pcu_cs  = 1;       // 11'C000 ~ 11'CFFF
        10'b01_??1?_?000: cab_cs  = 1;       // 12'0000           - LS138 @ 7E
        10'b01_??1?_?001: pair_cs = ~LDSn;   // 12'1000           - LS138 @ 7E
        10'b01_??1?_?010: {eep_wr,cfg_wr} = ~{UDWn,LDWn};
                                             // 12'2000           - LS138 @ 7E
        10'b01_??1?_?011: sndon   = 1;       // 12'3000           - LS138 @ 7E
        10'b10_????_????: vram_cs = 1;       // 20'0000 ~ 2F'FFFF - LS139 @ 3F
        10'b11_????_????: psvrm_cs= 1;       // 30'0000 ~ 3F'FFFF - LS139 @ 3F
        default:;
    endcase
`ifdef SIMULATION
    none_cs = ~BUSn & ~|{rom_cs, ram_cs, pal_cs, /*wdog,*/
        cab_cs, vram_cs, obj_cs, objset_cs, pcu_cs};
`endif
end

always @(posedge clk) begin
    IPLn    <= {tile_irqn,1'b1,tile_irqn};
    HALTn   <= dip_pause & ~rst;
    case( A[1] )
        0: cab_dout <= { dipsw[12+:4], 1'b1, coin[0], dip_test, service[0], cab_1p[0], joystick1[6:0] };
        1: cab_dout <= { 5'h1f, coin[1], eep_rdy, eep_do, cab_1p[1], joystick2[6:0] };
    endcase
    cpu_din <= rom_cs   ? rom_data         :
               ram_cs   ? ram_dout         :
               obj_cs   ? oram_dout        :
               vram_cs  ? {2{vram_dout}}   :
               pal_cs   ? pal_dout         :
               pslrm_cs ? lmem_dout        :
               pair_cs  ? {8'd0,pair_dout} :
               cab_cs   ? cab_dout         : 16'h0;
end

always @(posedge clk) begin
    if( rst ) begin
        eep_di    <= 0;
        eep_cs    <= 0;
        eep_clk   <= 0;
        zrmck     <= 0;
        psac_bank <= 0;
        obank     <= 0;
        rmrd      <= 0;
    end else begin
        if( eep_wr ) {  eep_clk, eep_cs, eep_di  } <= cpu_dout[10:8];
        if( cfg_wr ) { zrmck, obank, psac_bank, rmrd } <= cpu_dout[7:4];
    end
end

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

jtframe_68kdtack_cen #(.W(6),.RECOVERY(1)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ( ram_dsn   ),
    .num        ( 5'd1      ),  // numerator
    .den        ( 6'd3      ),  // denominator, 3 (16MHz)
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
    .HALTn      ( HALTn       ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( dtac    ),
    .IPLn       ( IPLn        ) // VBLANK
);
`else
    reg [7:0] saved[0:0];
    integer f,fcnt=0;

    initial begin
        f=$fopen("other.bin","rb");
        if( f!=0 ) begin
            fcnt=$fread(saved,f);
            $fclose(f);
            $display("Read %1d bytes for bank configuration", fcnt);
            {psac_bank,obank} = saved[0][1:0];
        end else begin
            {psac_bank,obank} = 0;
        end
    end
    initial begin
        obj_cs    = 0;
        objset_cs = 0;
        pal_cs    = 0;
        pcu_cs    = 0;
        ram_cs    = 0;
        rmrd      = 0;
        rom_cs    = 0;
        sndon     = 0;
        vram_cs   = 0;
        psreg_cs  = 0;
    end
    assign
        cpu_we    = 0,
        main_addr = 0,
        ram_dsn   = 0,
        lmem_we   = 0,
        pair_we   = 0,
        st_dout   = 0,
        nv_addr   = 0,
        nv_din    = 0,
        zrmck     = 0,
        cpu_dout  = 0,
        nv_we     = 0;
`endif
endmodule
