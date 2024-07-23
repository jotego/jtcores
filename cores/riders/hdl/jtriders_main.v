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
    Date: 7-7-2024 */

module jtriders_main(
    input                rst,
    input                clk, // 48 MHz
    input                LVBL,

    output        [19:1] main_addr,
    output        [ 1:0] ram_dsn,
    output        [15:0] cpu_dout,
    input                BRn,
    input                BGACKn,
    output               BGn,
    // 8-bit interface
    output               cpu_we,
    output reg           pal_cs,
    output reg           pcu_cs,
    // Sound interface
    output               snd_wrn,   // K053260 (PCM sound)
    input         [ 7:0] snd2main,  // K053260 (PCM sound)
    output reg           sndon,     // irq trigger

    output reg           rom_cs,
    output reg           ram_cs,
    output reg           vram_cs,
    output reg           obj_cs,

    input         [15:0] oram_dout,
    input         [15:0] prot_dout,
    input         [ 7:0] vram_dout,
    input         [15:0] pal_dout,
    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,
    input                vdtac,
    input                tile_irqn,
    input                prot_irqn,
    output reg           prot_cs,

    // video configuration
    output reg           objreg_cs,
    output reg           rmrd,
    output reg           dimmod,
    output reg           dimpol,
    output reg  [ 2:0]   dim,
    output reg  [ 2:0]   cbnk,      // unconnected in ssriders
    input                dma_bsy,
    // EEPROM
    output      [ 6:0]   nv_addr,
    input       [ 7:0]   nv_dout,
    output      [ 7:0]   nv_din,
    output               nv_we,
    // Cabinet
    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input         [ 6:0] joystick3,
    input         [ 6:0] joystick4,
    input         [ 3:0] cab_1p,
    input         [ 3:0] coin,
    input         [ 3:0] service,
    input                dip_pause,
    input                dip_test,
    output        [ 7:0] st_dout,
    input         [ 7:0] debug_bus
);
`ifndef NOMAIN
wire [23:1] A;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, allFC, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
reg         cab_cs, snd_cs, iowr_hi, iowr_lo, HALTn,
            eep_di, eep_clk, eep_cs;
reg  [15:0] cpu_din;
reg  [ 7:0] cab_dout;
wire        eep_rdy, eep_do, bus_cs, bus_busy, BUSn;
wire        dtac_mux;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign main_addr= A[19:1];
assign ram_dsn  = {UDSn, LDSn};
assign IPLn     = { tile_irqn, 1'b1, prot_irqn };
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | ( ram_cs & ~ram_ok);
assign BUSn     = ASn | (LDSn & UDSn);

assign cpu_we   = ~RnW;

assign st_dout  = 0; //{ rmrd, 1'd0, prio, div8, game_id };
assign VPAn     = ~&{ BGACKn, FC[1:0], ~ASn };
assign dtac_mux = DTACKn | ~vdtac;
assign snd_wrn  = ~(snd_cs & ~RnW);

reg none_cs, wdog;
// not following the PALs as the dumps from PLD Archive are not readable
// with MAME's JEDUTIL
always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    pal_cs   = 0;
    iowr_lo  = 0;
    iowr_hi  = 0;
    cab_cs   = 0;
    vram_cs  = 0; // tilesys_cs
    obj_cs   = 0;
    objreg_cs= 0;
    snd_cs   = 0;
    sndon    = 0;
    pcu_cs   = 0;
    prot_cs  = 0;
    wdog     = 0;
    if(!ASn) case(A[23:20])
        0: rom_cs = 1;
        1: case(A[19:18])
            0: ram_cs  = A[14] & ~BUSn;
            1: pal_cs  = 1;  // 14'xxxx
            2: obj_cs  = 1;  // 18'xxxx (not all A bits go to OBJ chip 053245)
            3: case(A[11:8]) // decoder 13G (pdf page 16)
              0,1: cab_cs  = 1;
                2: iowr_lo = 1; // EEPROM
                3: iowr_hi = 1;
                4: wdog    = 1;
                // 5: TMNT2 RAM
                8: prot_cs = 1;
                default:;
            endcase
            default:;
        endcase
        5: case(A[19:16])
            4'ha: objreg_cs = 1;
            4'hc: case(A[11:8]) // 13G
                6: begin
                    snd_cs = !A[2]; // 053260
                    sndon  =  A[2];
                end
                7: pcu_cs = 1;      // 053251
                default:;
                endcase
            default:;
            endcase
        6: vram_cs = 1; // probably different at boot time
        default:;
    endcase
`ifdef SIMULATION
    none_cs = ~BUSn & ~|{rom_cs, ram_cs, pal_cs, iowr_lo, iowr_hi, wdog,
        cab_cs, vram_cs, obj_cs, objreg_cs, snd_cs, sndon, pcu_cs, prot_cs};
`endif
end

always @(posedge clk) begin
    HALTn   <= dip_pause & ~rst;
    cpu_din <= rom_cs  ? rom_data        :
               ram_cs  ? ram_dout        :
               obj_cs  ? oram_dout       :
               prot_cs ? prot_dout       :
               vram_cs ? {2{vram_dout}}  :
               pal_cs  ? pal_dout        :
               snd_cs  ? {8'd0,snd2main} :
               cab_cs  ? {8'd0,cab_dout} : 16'hffff;
end

reg fake_dma=0, cabcs_l;

always @(posedge clk) begin
    if( cpu_cen ) begin
        cabcs_l <= cab_cs;
        if( !cab_cs && !cabcs_l ) fake_dma <= ~fake_dma;
    end
    cab_dout <= A[1] ? { dip_test, 2'b11, IPLn[0], LVBL, /*~dma_bsy*/fake_dma, eep_rdy, eep_do }:
                       { service, coin };
    case( {A[8],A[2:1]} )
        0: cab_dout <= { cab_1p[0], joystick1[6:0] };
        1: cab_dout <= { cab_1p[1], joystick2[6:0] };
        2: cab_dout <= { cab_1p[2], joystick3[6:0] };
        3: cab_dout <= { cab_1p[3], joystick4[6:0] };
        default:;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dim     <= 0;
        rmrd    <= 0;
        dimpol  <= 0;
        dimmod  <= 0;
        eep_di  <= 0;
        eep_cs  <= 0;
        eep_clk <= 0;
        cbnk    <= 0;
    end else begin
        if( iowr_lo  ) { cbnk, dimpol, dimmod, eep_clk, eep_cs, eep_di } <= cpu_dout[7:0];
        if( iowr_hi  ) { dim, rmrd } <= cpu_dout[6:3];
    end
end

jt5911 #(.SIMFILE("nvram.bin"),.SYNHEX("default.hex")) u_eeprom(
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

// The board seems to control DTACKn with combinational logic
// DTACKn follows ASn with a delay of ~15.6ns
jtframe_68kdtack_cen #(.W(6),.RECOVERY(1)) u_dtack(
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
    .BRn        ( BRn         ),
    .BGACKn     ( BGACKn      ),
    .BGn        ( BGn         ),

    .DTACKn     ( dtac_mux    ),
    .IPLn       ( IPLn        ) // VBLANK
);
`else
    initial begin
        sndon   = 0;
        obj_cs  = 0;
        pal_cs  = 0;
        pcu_cs  = 0;
        prio    = 0;
        ram_cs  = 0;
        rmrd    = 0;
        rom_cs  = 0;
        vram_cs = 0;
    end
    assign
        cpu_dout  = 0,
        cpu_we    = 0,
        main_addr = 0,
        ram_dsn   = 0,
        snd_wrn   = 0,
        st_dout   = 0;
`endif
endmodule
