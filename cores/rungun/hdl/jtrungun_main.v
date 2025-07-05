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
    input                disp,

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
    input         [15:0] vram_dout,
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
    output        [ 3:0] psac_bank,
    output               gvflip, ghflip,
    output               pri,
    input                dma_bsy,
    // EEPROM
    output        [ 6:0] nv_addr,
    input         [ 7:0] nv_dout,
    output        [ 7:0] nv_din,
    output               nv_we,
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
reg  [15:0] cab_dout;
wire        cpu_cen, cpu_cenb,
            fmode, fsel,
            UDSn, LDSn, RnW, ASn, BUSn,
            eep_rdy, eep_do, eep_di, eep_clk, eep_cs;
reg         boot_cs, xrom_cs, gfx_cs, sys2_cs, sys1_cs, lrsw,
            io1_cs, io2_cs, io_cs, misc_cs, HALTn;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign ram_dsn  = {UDSn, LDSn};
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | (ram_cs & ~ram_ok);
assign BUSn     = ASn | (LDSn & UDSn);
assign cpu_we   = ~RnW;
assign pri      = sys1_dout[14];
assign gvflip   = sys1_dout[ 6];
assign ghflip   = sys1_dout[ 5];
assign eep_di   = sys1_dout[ 0];
assign eep_clk  = sys1_dout[ 2];
assign eep_cs   = sys1_dout[ 1];
assign psac_bank= sys2_dout[7:4];
assign fmode    = sys2_dout[ 1];
assign fsel     = sys2_dout[ 0];

assign lrsw     = fmode ? disp : fsel;

always @* begin
    boot_cs =   !ASn  &&  A[23:20]==0 && RnW;
    xrom_cs =   !ASn  && (A[23:20]==2 || A[23:20]==1);
    ram_cs  =   !ASn  &&  A[23:19]==5'b1_0 && !BUSn;
    gfx_cs  =   !ASn  &&  A[23:21]==3'b011;
    misc_cs =   !ASn  &&  A[23:21]==3'b010;
    vram_cs = gfx_cs  &&  A[20:18]==5;
    io_cs   = misc_cs &&  A[20:18]==2;
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
    endcase
end

always @(posedge clk) begin
    cab1_dout <= A[1] ? {cab_1p[3],joystick4,cab_1p[1],joystick2}:
                        {cab_1p[2],joystick3,cab_1p[0],joystick1};
    cab2_dout <= { lrsw, odma, A[1] ? {dipsw, dip_test, 1'b1, eep_rdy, eep_do }:
                                      {service,   coin};
    cab_dout  <= io1_cs ? cab1_dout : {6'd0, cab2_dout};
    HALTn   <= dip_pause & ~rst;
    cpu_din <= rom_cs  ? rom_data        :
               ram_cs  ? ram_dout        :
               vram_cs ? vram_dout       :
               cab_cs  ? cab_dout        : 16'h0;
end

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
