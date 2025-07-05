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
    input                rst,
    input                clk, // 48 MHz
    input                LVBL,

    output        [21:1] main_addr,
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
wire        cpu_cen, cpu_cenb,
            UDSn, LDSn, RnW, ASn, BUSn;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign ram_dsn  = {UDSn, LDSn};
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | (ram_cs & ~ram_ok);
assign BUSn     = ASn | (LDSn & UDSn);

always @* begin
    boot_cs = !ASn &&  A[23:20]==0 && RnW;
    xrom_cs = !ASn && (A[23:20]==2 || A[23:20]==1);
    ram_cs  = !ASn &&  A[23:19]==5'b1_0 && !BUSn;
end

always @* begin
    rom_cs    = boot_cs | xrom_cs;
    main_addr = A[21:1];
    if(boot_cs) main_addr[21:20]=0;
    if(rom_cs ) case(A[21:20])
        1: main_addr[21:20] = 2'b10;
        2: main_addr[21:20] = 2'b01;
    endcase
end

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
