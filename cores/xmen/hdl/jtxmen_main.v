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

module jtxmen_main(
    input                rst,
    input                clk, // 48 MHz
    input                LVBL,

    output        [19:1] main_addr,
    output        [ 1:0] ram_dsn,
    output        [15:0] cpu_dout,
    // 8-bit interface
    output               cpu_we,
    output reg           pal_cs,
    output reg           pcu_cs,
    // Sound interface
    output               pair_we,   // K054321 (some latches)
    input         [ 7:0] pair_dout, // K054321 (X-Men)
    output               snd_wrn,   // K053260 (PCM sound)
    input         [ 7:0] snd2main,  // K053260 (PCM sound)
    output reg           sndon,     // irq trigger
    output reg           mute,

    output reg           rom_cs,
    output reg           ram_cs,
    output reg           vram_cs,
    output reg           obj_cs,

    input         [15:0] oram_dout,
    input         [ 7:0] vram_dout,
    input         [15:0] pal_dout,
    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,
    input                vdtac,
    input                tile_irqn,

    // video configuration
    output reg           objreg_cs,
    output reg           objcha_n,
    output reg           rmrd,
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
wire [ 2:0] FC;
reg  [ 2:0] IPLn;
reg         cab_cs, snd_cs, iowr_hi, iowr_lo, HALTn,
            eep_di, eep_clk, eep_cs, intdma_enb,
            sndon_r, pair_cs;
reg  [15:0] cpu_din, cab_dout;
wire        eep_rdy, eep_do, bus_cs, bus_busy, BUSn;
wire        dtac_mux, intdma, IPLn1;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif
/* verilator tracing_off */
assign main_addr= A[19:1];
assign ram_dsn  = {UDSn, LDSn};
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | (ram_cs & ~ram_ok);
assign BUSn     = ASn | (LDSn & UDSn);

assign cpu_we   = ~RnW;

assign st_dout  = 0; //{ rmrd, 1'd0, prio, div8, game_id };
assign VPAn     = ~&{ FC[1:0], ~ASn };
assign dtac_mux = DTACKn | ~vdtac;
assign snd_wrn  = ~(snd_cs & ~RnW);
assign IPLn1    = ~intdma | tile_irqn;
assign pair_we  = pair_cs && !RnW && !LDSn;

reg none_cs;
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
    sndon    = sndon_r;
    pcu_cs   = 0;
    pair_cs  = 0;
    if(!ASn) begin
    // xmen (from PAL equations)
        rom_cs  = ~A[20];
        ram_cs  =  A[20:14]==7'b1000100 & ~BUSn;
        obj_cs  =  A[20:14]==7'b1000000;
        pal_cs  =  A[20:13]==8'b10000010;
        vram_cs = ~A[23] & A[20] & A[19];
        iowr_lo =  A[20:13]==8'b1_0000_100; // IO1 in schematics
        iowr_hi =  A[20:13]==8'b1_0000_101; // IO2 in schematics
        cab_cs  = iowr_hi && !A[3];
        // cr_cs = iowr_hi && A[3:2]==3;
        objreg_cs = iowr_lo && A[6:5]==1;
        pair_cs   = iowr_lo && A[6:5]==2;
        pcu_cs    = iowr_lo && A[6:5]==3;
    end
`ifdef SIMULATION
    none_cs = ~BUSn & ~|{rom_cs, ram_cs, pal_cs, iowr_lo, iowr_hi,
        cab_cs, vram_cs, obj_cs, objreg_cs, snd_cs, sndon, pcu_cs};
`endif
end

jtframe_edge #(.QSET(0)) u_ff(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .edgeof     ( dma_bsy   ),
    .clr        (~intdma_enb),
    .q          ( intdma    )
);

always @(posedge clk) begin
    IPLn <= { intdma | ~IPLn1, IPLn1, intdma & tile_irqn };

    HALTn   <= dip_pause & ~rst;
    cpu_din <= rom_cs  ? rom_data        :
               ram_cs  ? ram_dout        :
               obj_cs  ? oram_dout       :
               vram_cs ? {2{vram_dout}}  :
               pal_cs  ? pal_dout        :
               snd_cs  ? {8'd0,snd2main} :
               pair_cs ? {8'd0,pair_dout}:
               cab_cs  ? cab_dout        : 16'hffff;
end

reg fake_dma=0, cabcs_l;

function [6:0] swap( input [6:0] joy );
begin
    swap = { joy[6:4],joy[1:0],joy[3:2]};
end
endfunction

always @(posedge clk) begin
    if( cpu_cen ) begin
        cabcs_l <= cab_cs;
        if( !cab_cs && !cabcs_l ) fake_dma <= ~fake_dma;
    end
    cab_dout <= A[1] ? { coin[2], swap(joystick3[6:0]), coin[0], swap(joystick1[6:0]) }:
                       { coin[3], swap(joystick4[6:0]), coin[1], swap(joystick2[6:0]) };
    if(A[3:2]==1) cab_dout <= { 1'b1, dip_test,
            2'b11, cab_1p[3:0],
            eep_rdy, eep_do, 2'b11, service };
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rmrd    <= 0;
        eep_di  <= 0;
        eep_cs  <= 0;
        eep_clk <= 0;
        sndon_r <= 0;
        mute    <= 0;
        objcha_n<= 1;
        intdma_enb <= 1;
    end else begin
        // xmen
        if( iowr_lo && A[6:5]==0 ) begin
            if( !LDSn ) { intdma_enb, eep_cs, eep_clk, eep_di } <= cpu_dout[5:2];
            if( !UDSn ) begin
                mute     <=  cpu_dout[11];
                sndon_r  <=  cpu_dout[10];
                rmrd     <=  cpu_dout[9];
                objcha_n <= ~cpu_dout[8];
            end
        end
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
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( dtac_mux    ),
    .IPLn       ( IPLn        ) // VBLANK
);
`else
    reg [7:0] saved[0:0];
    integer f,fcnt=0;

    // initial begin
    //     f=$fopen("other.bin","rb");
    //     if( f!=0 ) begin
    //         fcnt=$fread(saved,f);
    //         $fclose(f);
    //         $display("Read %1d bytes for dimming configuration", fcnt);
    //         {dimmod,dimpol,dim} = {saved[0][5:4],saved[0][2:0]};
    //     end else begin
    //         {dimmod,dimpol,dim} = 0;
    //     end
    // end
    initial begin
        obj_cs    = 0;
        objcha_n  = 1;
        objreg_cs = 0;
        pal_cs    = 0;
        pcu_cs    = 0;
        ram_cs    = 0;
        rmrd      = 0;
        rom_cs    = 0;
        sndon     = 0;
        vram_cs   = 0;
        mute      = 0;
    end
    assign
        cpu_dout  = 0,
        cpu_we    = 0,
        main_addr = 0,
        ram_dsn   = 0,
        snd_wrn   = 0,
        st_dout   = 0,
        nv_addr   = 0,
        nv_din    = 0,
        pair_we   = 0,
        nv_we     = 0;
`endif
endmodule
