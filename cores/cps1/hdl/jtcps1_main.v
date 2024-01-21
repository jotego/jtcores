/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-1-2020 */

module jtcps1_main(
    input              rst,
    input              clk,
    output             cen10,
    output             cen10b,
    input              turbo,
    output             cpu_cen,
    // Timing
    input   [8:0]      V,
    input              LVBL,
    input              LHBL,
    // PPU
    output reg         ppu1_cs,
    output reg         ppu2_cs,
    output reg         ppu_rstn,
    input   [15:0]     mmr_dout,
    input   [ 1:0]     joymode,
    // Sound
    output  reg  [7:0] snd_latch0,
    output  reg  [7:0] snd_latch1,
    output             UDSWn,
    output             LDSWn,
    // cabinet I/O
    input              charger,
    input   [9:0]      joystick1,
    input   [9:0]      joystick2,
    input   [1:0]      dial_x,
    input   [1:0]      dial_y,
    `ifdef CPS15
    input   [9:0]      joystick3,
    input   [9:0]      joystick4,
    input   [3:0]      cab_1p,
    input   [3:0]      coin,
    `else
    input   [1:0]      cab_1p,
    input   [1:0]      coin,
    `endif
    input              service,
    input              tilt,
    // BUS sharing
    input              busreq,
    output             busack,
    output             RnW,
    // For RAM/ROM:
    output      [17:1] addr,
    output      [15:0] cpu_dout,
    // RAM access
    output reg         ram_cs,
    output reg         vram_cs,
    input       [15:0] ram_data,
    input              ram_ok,
    // ROM access
    output reg         rom_cs,
    output reg  [21:1] rom_addr,
    input       [15:0] rom_data,
    input              rom_ok,
    // DIP switches
    input              dip_pause,
    input              dip_test,
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b,
    input    [7:0]     dipsw_c
    // QSound
    `ifdef CPS15 ,
    output reg         eeprom_sclk,
    output reg         eeprom_sdi,
    input              eeprom_sdo,
    output reg         eeprom_scs,
    input       [ 7:0] main2qs_din,
    output reg  [23:1] main2qs_addr,
    output reg         main2qs_cs,
    input              main2qs_busakn,
    input              main2qs_waitn
    `endif
);

wire [23:1] A;
wire        BERRn = 1'b1;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

(*keep*) wire        BRn, BGACKn, BGn;
(*keep*) wire        ASn;
reg         io_cs, joy_cs, eeprom_cs,
            sys_cs, olatch_cs, snd1_cs, snd0_cs, dial_cs;
reg         dsn_dly;

reg         sys_sel;
`ifdef CPS15
reg         io15_cs, joy3_cs, joy4_cs;
`else
wire        joy3_cs=0, joy4_cs=0;
`endif

assign cpu_cen   = cen10;
// As RAM and VRAM share contiguous spaces in the SDRAM
// it is important to prevent overlapping
assign addr      = ram_cs ? {2'b0, A[15:1] } : A[17:1];

// high during DMA transfer
wire UDSn, LDSn;
assign UDSWn = RnW | UDSn;
assign LDSWn = RnW | LDSn;

// PAL BUF1 16H
// buf0 = A[23:16]==1001_0000 = 8'h90
// buf1 = A[23:16]==1001_0001 = 8'h91
// buf2 = A[23:16]==1001_0010 = 8'h92

`ifdef SIMULATION
    // This signal is present in the schematics
    reg one_wait;

    always @(*) begin
        one_wait = !ASn && BGACKn && (A[23] || A[23:22]==2'b0); // RAM or ROM // A[23] | ~A[22];
    end
`endif

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_cs      <= 1'b0;
        ram_cs      <= 1'b0;
        vram_cs     <= 1'b0;
        // dbus_cs     <= 1'b0;
        io_cs       <= 1'b0;
        joy_cs      <= 1'b0;
        sys_cs      <= 1'b0;
        olatch_cs   <= 1'b0;
        snd1_cs     <= 1'b0;
        snd0_cs     <= 1'b0;
        ppu1_cs     <= 1'b0;
        ppu2_cs     <= 1'b0;
        dial_cs     <= 1'b0;
        rom_addr    <= 21'd0;
        `ifdef CPS15
        io15_cs     <= 0;
        joy3_cs     <= 0;
        joy4_cs     <= 0;
        eeprom_cs   <= 0;
        main2qs_cs   <= 0;
        main2qs_addr <= 23'd0;
        `endif
    end else begin
        if( !ASn && BGACKn && (RnW || {UDSn,LDSn}!=3) ) begin // PAL PRG1 12H
            rom_addr    <= A[21:1];
            rom_cs      <= A[23:22] == 2'b00;
            // dbus_cs     <= ~|A[23:18]; // all must be zero
            vram_cs     <= A[23:18] == 6'b1001_00 && A[17:16]!=2'b11;
            io_cs       <= A[23:20] == 4'b1000;
            ram_cs      <= &A[23:18];
            `ifdef CPS15
            io15_cs      <= A[23:12] == 12'hf1C;
            main2qs_cs   <= A[23:20] == 4'hf  && A[19:17]==3'd0 && (
                            !A[16] ||                             // F00000-F0FFFF
                            (A[16] && A[15] && (A[14]==A[13])) ); // F18000~F19FFF F1E000~F1FFFF
            main2qs_addr <= A;
            `endif
            if( io_cs ) begin // PAL IOA1 (16P8B @ 12F)
                ppu1_cs  <= A[8:6] == 3'b100; // 'h10x
                ppu2_cs  <= A[8:6] == 3'b101 /* 'h14x */ || A[8:6] == 3'b111; /* 'h1Cx */
                dial_cs  <= A[8:5] == 4'b0_010;    // 0x800040/50
                if( RnW ) begin
                    joy_cs  <= A[8:3] == 6'b0_0000_0; // 0x800000
                    sys_cs  <= A[8:3] == 6'b0_0001_1; // 0x800018
                end else begin // outputs
                    olatch_cs <= !UDSWn && A[8:3]==6'b00_0110;
                    `ifndef CPS15
                    snd1_cs   <= !LDSWn && A[8:3]==6'b11_0001;
                    snd0_cs   <= !LDSWn && A[8:3]==6'b11_0000;
                    `endif
                end
            end
            `ifdef CPS15
            if( io15_cs ) begin
                joy3_cs   <= A[2:1]==2'd0;
                joy4_cs   <= A[2:1]==2'd1;
                // coin2_cs   <= A[3:2]==2'd2;
                eeprom_cs <= A[2:1]==2'd3;
            end
            `endif
        end else begin
            rom_cs      <= 1'b0;
            ram_cs      <= 1'b0;
            vram_cs     <= 1'b0;
            // dbus_cs     <= 1'b0;
            io_cs       <= 1'b0;
            joy_cs      <= 1'b0;
            sys_cs      <= 1'b0;
            olatch_cs   <= 1'b0;
            snd1_cs     <= 1'b0;
            snd0_cs     <= 1'b0;
            ppu1_cs     <= 1'b0;
            ppu2_cs     <= 1'b0;
            dial_cs     <= 1'b0;
            `ifdef CPS15
            io15_cs     <= 0;
            eeprom_cs   <= 0;
            joy3_cs     <= 0;
            joy4_cs     <= 0;
            main2qs_cs  <= 0;
            `endif
        end
    end
end

/*
`ifdef SIMULATION
always @(posedge one_wait) begin
    $display("one_wait went high at %t",$time());
    #1000 $finish;
end
`endif
*/
// special registers
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ppu_rstn   <= 1'b0;
        snd_latch0 <= 8'd0;
        snd_latch1 <= 8'd0;
    end
    else if(cpu_cen) begin
        if( olatch_cs ) begin
            // coin counters and lockers should go in here too
            ppu_rstn <= ~cpu_dout[15];
        end
        if( snd0_cs ) snd_latch0 <= cpu_dout[7:0];
        if( snd1_cs ) snd_latch1 <= cpu_dout[7:0];
    end
end

`ifdef CPS15
// EEPROM control in CPS 1.5 games
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        eeprom_scs  <= 0;
        eeprom_sclk <= 0;
        eeprom_sdi  <= 0;
    end
    else if(cpu_cen) begin
        if( eeprom_cs && !LDSWn ) begin
            eeprom_scs  <= cpu_dout[7];
            eeprom_sclk <= cpu_dout[6];
            eeprom_sdi  <= cpu_dout[0];
        end
    end
end
`endif

// incremental encoder counter
wire [7:0] dial_dout;
`ifndef CPS15
    wire       dial_rst  = dial_cs && !RnW && ~A[4];
    wire       xn_y      = A[3];
    wire       x_rst     = dial_rst & ~xn_y;
    wire       y_rst     = dial_rst &  xn_y;

    jt4701 u_dial(
        .clk        ( clk       ),
        .rst        ( rst       ),
        .x_in       ( dial_x    ),
        .y_in       ( dial_y    ),
        .rightn     ( 1'b1      ),
        .leftn      ( 1'b1      ),
        .middlen    ( 1'b1      ),
        .x_rst      ( x_rst     ),
        .y_rst      ( y_rst     ),
        .csn        ( ~dial_cs  ),        // chip select
        .uln        ( ~A[1]     ),        // byte selection
        .xn_y       ( xn_y      ),        // select x or y for reading
        .cfn        (           ),        // counter flag
        .sfn        (           ),        // switch flag
        .dir        (           ),
        .dout       ( dial_dout )
    );
`else
    assign dial_dout = 0;
`endif

reg [15:0] sys_data;
reg [ 1:0] dial_xl;
reg        dial_en;

// Detects the dial
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dial_en <= 0;
        dial_xl <= 0;
    end else if( !LVBL && last_LVBL ) begin
        dial_xl <= dial_x;
        if( dial_xl != dial_x ) dial_en <= 1;
    end
end

always @(posedge clk) begin
`ifdef CPS15
    if( joy_cs ) begin
        sys_data     <= { joystick2[7:0], joystick1[7:0] };
        sys_data[7]  <= joystick3[6]; // button 3
        sys_data[15] <= joystick4[6]; // button 3
    end else if( joy3_cs )
        sys_data <= { 2{cab_1p[2], coin[2], joystick3[5:0] }};
    else if( joy4_cs )
        sys_data <= { 2{cab_1p[3], coin[3], joystick4[5:0] }};
`else
    if( joy_cs ) begin
        sys_data <= { joystick2[7:0], joystick1[7:0] };
        if( !joymode[0] && dial_en ) begin
            sys_data[1:0] <= dial_x;
        end
    end
`endif
    else if(sys_cs) begin
        case( A[2:1] )
            2'b00: sys_data <=
            charger ? // Support for SFZ charger version
              { joystick2[9], joystick1[9], cab_1p[1:0],
               &coin[1:0], service, joystick2[8], joystick1[8], 8'hff } :
            // Regular CPS1 arcade:
            { tilt,
                `ifdef CPS15
                dip_test /* alternative test dip */,
                `else
                1'b1,
                `endif
                cab_1p[1:0],
                1'b1, service, coin[1:0], 8'hff };
            2'b01: sys_data <= { dipsw_a, 8'hff };
            2'b10: sys_data <= { dipsw_b, 8'hff };
            2'b11: sys_data <= { dipsw_c, 8'hff };
        endcase
    end
    else if( dial_cs && A[4] && RnW ) begin
            sys_data <= { 8'hff, dial_dout };
    end
    else sys_data <= 16'hffff;
end

// Data bus input
reg  [15:0] cpu_din;

always @(posedge clk) begin
    if(rst) begin
        cpu_din <= 16'hffff;
    end else begin
        sys_sel <= dial_cs | joy_cs | joy3_cs | joy4_cs | sys_cs;
        cpu_din <= sys_sel              ? sys_data : (
                   (ram_cs | vram_cs )  ? ram_data : (
                    rom_cs              ? rom_data : (
                    ppu2_cs             ? mmr_dout : (
                    `ifdef CPS15
                    eeprom_cs           ? {~15'd0, eeprom_sdo}  : (
                    main2qs_cs          ? {8'hff, main2qs_din} :
                    `else
                    (
                    `endif
                                        16'hFFFF )))));

    end
end

// DTACKn generation
wire       inta_n;
wire       bus_cs =   |{
`ifdef CPS15
    main2qs_cs,
`endif
    rom_cs, ram_cs, vram_cs };

wire       bus_busy = |{
`ifdef CPS15
    main2qs_cs & ~main2qs_waitn,
`endif
    rom_cs & ~rom_ok,
    (ram_cs|vram_cs) & ~ram_ok };
//                          wait_cycles[0] };
wire       DTACKn;
reg        last_LVBL;
wire       dtack_clr;

`ifdef CPS15
    reg qs_busakn_s;

    always @(posedge clk, posedge rst) begin
        if( rst )
            qs_busakn_s <= 1;
        else if(cpu_cen)
            qs_busakn_s <= main2qs_busakn;
    end
    assign dtack_clr = main2qs_cs & qs_busakn_s; // do not count until the bus is granted
`else
    assign dtack_clr = 0;
`endif

wire [3:0] cen_num;
wire [4:0] cen_den;

assign cen_num = turbo ? 4'd1 : 4'd5;
assign cen_den = turbo ? 5'd4 : 5'd24;

jtframe_68kdtack_cen u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cen10     ),
    .cpu_cenb   ( cen10b    ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .ASn        ( ASn | dtack_clr ),
    .DSn        ( {UDSn, LDSn} ),
    .num        ( cen_num  ),
    .den        ( cen_den   ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    // unused
    .fave       (           ),
    .fworst     (           ),
    .frst       (           )
);

// interrupt generation
reg        int1, // VBLANK
           int2; // ??
(*keep*) wire [2:0] FC;
assign inta_n = ~&{ FC[2], FC[1], FC[0], ~ASn }; // interrupt ack.

always @(posedge clk, posedge rst) begin : int_gen
    //reg last_V256;
    if( rst ) begin
        int1 <= 1'b1;
        int2 <= 1'b1;
    end else begin
        last_LVBL <= LVBL;
        //last_V256 <= V[8];

        if( !inta_n ) begin
            int1 <= 1'b1;
            int2 <= 1'b1;
        end
        else begin
            //if( V[8] && !last_V256 ) int2 <= 1'b0;
            if( !LVBL && last_LVBL ) int1 <= 1'b0;
        end
    end
end

assign busack = ~BGACKn;

jtframe_68kdma #(.BW(1)) u_arbitration(
    .clk        (  clk          ),
    .cen        ( cen10b        ),
    .rst        (  rst          ),
    .cpu_BRn    (  BRn          ),
    .cpu_BGACKn (  BGACKn       ),
    .cpu_BGn    (  BGn          ),
    .cpu_ASn    (  ASn          ),
    .cpu_DTACKn (  DTACKn       ),
    .dev_br     (  busreq       )
);

fx68k u_cpu(
    .clk        ( clk         ),
    .extReset   ( rst         ),
    .pwrUp      ( rst         ),
    .enPhi1     ( cen10       ),
    .enPhi2     ( cen10b      ),

    // Buses
    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),


    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( inta_n      ),
    .FC0        ( FC[0]       ),
    .FC1        ( FC[1]       ),
    .FC2        ( FC[2]       ),

    .BERRn      ( BERRn       ),
    // Bus arbitrion
    .HALTn      ( dip_pause   ),
    .BRn        ( BRn         ),
    .BGACKn     ( BGACKn      ),
    .BGn        ( BGn         ),

    .DTACKn     ( DTACKn      ),
    .IPL0n      ( 1'b1        ),
    .IPL1n      ( int1        ), // VBLANK
    .IPL2n      ( int2        ),

    // Unused
    .oRESETn    (             ),
    .oHALTEDn   (             ),
    .VMAn       (             ),
    .E          (             )
);

`ifdef SIMULATION
wire BUSn = ASn | (LDSn & UDSn);

integer fdebug;

initial begin
    fdebug=$fopen("debug.log","w");
end

always @(posedge rom_cs) begin
    $fdisplay(fdebug,"%X",A_full);
end
`endif

`ifdef CPS15
`ifdef SIMULATION
integer fqmem;
integer frame_cnt;

initial begin
    fqmem=$fopen("qmem.log","w");
    frame_cnt = 0;
end

always @(negedge LVBL ) frame_cnt <= frame_cnt+1;

always @(posedge cpu_cen) begin
    if( main2qs_cs && !DTACKn ) begin
        if( !LDSWn ) begin
            $fdisplay( fqmem, "%04d Write %08X %02X", frame_cnt, A_full, cpu_dout[7:0]);
        end else begin
            $fdisplay( fqmem, "%04d Read  %08X %02X", frame_cnt, A_full, main2qs_din );

        end
    end
end

`endif
`endif

endmodule
