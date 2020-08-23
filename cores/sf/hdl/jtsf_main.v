/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 16-8-2020 */

// Street Fighter: Main CPU
// 8MHz 68000 CPU

// PAL devices
// SF13 - Location 8B, board C, address decoder
// according to dump from https://www.jammarcade.net/wiki/index.php?title=Street_Fighter
//       /o12 = /i4 & i7 & i8 & i9
//        o14 = i2 & i4 & /i17
//        o15 = i5 & i6
//        o16 = /i3 & i5
//       /o19 = /i1 & /i3


module jtsf_main #(
    parameter MAINW = 18,
              RAMW  = 15
) (
    input              rst,
    input              clk,
    input              cen8,
    input              cen8b,
    output             cpu_cen,
    // Timing
    output reg         flip,
    input       [ 8:0] V,
    input              LHBL,
    input              LVBL,
    // Sound
    output reg  [ 7:0] snd_latch,
    output reg         snd_nmi_n,
    // Characters
    input       [15:0] char_dout,
    output      [15:0] cpu_dout,
    output reg         char_cs,
    input              char_busy,
    output             UDSWn,
    output             LDSWn,
    // scroll
    output reg  [15:0] scr1posh,
    output reg  [15:0] scr2posh,
    // GFX enable signals
    output reg         charon,
    output reg         scr1on,
    output reg         scr2on,
    output reg         objon,
    // cabinet I/O
    input       [ 9:0] joystick1,
    input       [ 9:0] joystick2,
    input       [ 1:0] start_button,
    input       [ 1:0] coin_input,
    input              service,
    // BUS sharing
    output      [13:1] cpu_AB,
    input       [12:0] obj_AB,
    output             RnW,
    output reg         OKOUT,
    input              obj_br,   // Request bus
    output             bus_ack,  // bus acknowledge
    input              blcnten,  // bus line counter enable
    // Palette
    output             col_uw,
    output             col_lw,
    // Memory address for SDRAM
    output   [MAINW:1] addr,
    // RAM access
    output             ram_cs,
    output  [RAMW-1:0] ram_addr,
    input       [15:0] ram_data,
    input              ram_ok,
    // ROM access
    output reg         rom_cs,
    input       [15:0] rom_data,
    input              rom_ok,
    // DIP switches
    input              dip_pause,
    input       [15:0] dipsw_a,
    input       [15:0] dipsw_b
);

wire [23:1] A;
reg  [15:0] cabinet_input, cpu_din;
wire        BRn, BGACKn, BGn;
reg         io_cs, pre_ram_cs, reg_ram_cs, obj_cs, col_cs,
            misc_cs, snd_cs;
reg         scr1pos_cs, scr2pos_cs;
wire        ASn, CPUbus;
wire        UDSn, LDSn;
reg         BERRn;

assign cpu_cen = cen8;
// high during DMA transfer
assign UDSWn    = RnW | UDSn;
assign LDSWn    = RnW | LDSn;
assign CPUbus   = !blcnten; // main CPU in control of the bus
assign ram_addr = CPUbus ? A[RAMW:1] : { 2'b11, obj_AB };

assign col_uw   = col_cs & ~UDSWn;
assign col_lw   = col_cs & ~LDSWn;
assign addr     = A[MAINW:1];
assign cpu_AB   = A[13:1];

`ifdef SIMULATION
wire [24:0] A_full = {A,1'b0};
`endif

always @(*) begin
    rom_cs     = 0;
    pre_ram_cs = 0;
    col_cs     = 0;
    io_cs      = 0;
    char_cs    = 0;
    OKOUT      = 0;
    misc_cs    = 0;
    snd_cs     = 0;
    // mcu_DMAONn = 1;   // for once, I leave the original active low setting
    scr1pos_cs = 0;
    scr2pos_cs = 0;
    snd_nmi_n  = 1;

    BERRn      = 1;

    if( !ASn && BGACKn ) case(A[23:20])
            4'h0: rom_cs  = 1;
            4'h8: char_cs = 1;
            4'hb: col_cs  = 1;
            4'hf: pre_ram_cs = A[15]; // 32kB!
            4'hc: if(A[19:16]==4'd0) begin
                io_cs = !A[4] && RnW;
                if( A[4] && !RnW ) case(A[3:1])
                    // 3'd1: coin_cs    = 1;  // coin counters
                    3'd2: scr1pos_cs = 1;
                    3'd4: scr2pos_cs = 1;
                    3'd5: begin
                        misc_cs = 1;
                        OKOUT   = 1;
                    end
                    3'd6: begin
                        //OKOUT   = !UDSn; // c0001c
                        snd_cs  = !LDSn; // c0001d
                        snd_nmi_n = 0;
                    end
                    default:;
                endcase
            end
            //default: BERRn = ASn;
            default:;
        endcase
end

// SCROLL 1/2 H POSITION
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scr1posh <= 16'd0;
        scr2posh <= 16'd0;
    end else if(cpu_cen) begin
        if( scr1pos_cs ) begin
            if(!UDSWn) scr1posh[15:8] <= cpu_dout[15:8];
            if(!LDSWn) scr1posh[ 7:0] <= cpu_dout[ 7:0];
        end
        if( scr2pos_cs ) begin
            if(!UDSWn) scr2posh[15:8] <= cpu_dout[15:8];
            if(!LDSWn) scr2posh[ 7:0] <= cpu_dout[ 7:0];
        end
    end
end

// special registers
always @(posedge clk) begin
    if( rst ) begin
        flip         <= 0;
        snd_latch    <= 8'b0;
        charon       <= 1;
        scr1on       <= 1;
        scr2on       <= 1;
        objon        <= 1;
    end
    else if(cpu_cen) begin
        if( misc_cs) begin
            if( !LDSWn ) begin
                flip   <= cpu_dout[2];
                charon <= cpu_dout[3];
                scr1on <= cpu_dout[5];
                scr2on <= cpu_dout[6];
                objon  <= cpu_dout[7];
            end
        end
        if( !UDSWn && snd_cs ) begin
            snd_latch <= cpu_dout[7:0];
        end
    end
end

// ram_cs and vram_cs signals go down before DSWn signals
// that causes a false read request to the SDRAM. In order
// to avoid that a little bit of logic is needed:
reg    dsn_dly;

assign ram_cs  = dsn_dly ? reg_ram_cs  : pre_ram_cs;

always @(posedge clk) if(cen8) begin
    reg_ram_cs  <= pre_ram_cs;
    dsn_dly     <= &{UDSWn,LDSWn}; // low if any DSWn was low
end

// Cabinet input
localparam BUT1=4, BUT2=5, BUT3=6, BUT4=7, BUT5=8, BUT6=9;

always @(posedge clk) if(io_cs) begin
    case( A[3:1] )
        3'd0: cabinet_input <= { // IN0 in MAME
                4'hf, // 15-12
                1'b1, // 11
                joystick2[BUT3], // 10
                joystick1[BUT3], // 9
                joystick2[BUT6], // 8
                5'h1f,           // 7-3
                joystick1[BUT6], // 2
                coin_input       // 1-0
            };
        3'd1: cabinet_input <= { // IN1 in MAME
            joystick2[BUT5],
            joystick2[BUT4],
            joystick2[BUT2],
            joystick2[BUT1],
            joystick2[3:0],
            joystick1[BUT5],
            joystick1[BUT4],
            joystick1[BUT2],
            joystick1[BUT1],
            joystick1[3:0]
        };
        3'd4: cabinet_input <= dipsw_b;
        3'd5: cabinet_input <= dipsw_a;
        3'd6: cabinet_input <= { // SYS
            8'hff,
            LVBL, // freeze when high
            4'hf,
            service,
            start_button
        };
        default: cabinet_input <= 16'hffff;
    endcase
end

// Data bus input
always @(*) begin
    case( {ram_cs, char_cs, io_cs} )
        3'b100:  cpu_din = ram_data;
        3'b010:  cpu_din = char_dout;
        3'b001:  cpu_din = cabinet_input;
        default: cpu_din = rom_data;
    endcase
end

// DTACKn generation
wire       int1, int2;
wire [2:0] FC;
wire       inta_n;
wire       bus_cs =   |{ rom_cs, char_cs, ram_cs };
wire       bus_busy = |{ rom_cs & ~rom_ok, char_busy, pre_ram_cs & ~ram_ok };
reg DTACKn;

always @(posedge clk, posedge rst) begin : dtack_gen
    reg       last_ASn;
    if( rst ) begin
        DTACKn <= 1'b1;
    end else if(cen8b) begin
        last_ASn <= ASn;
        if( !ASn && last_ASn ) begin
            DTACKn <= 1;
        end else if( !ASn ) begin
            if( bus_cs ) begin
                if (!bus_busy) DTACKn <= 0;
            end
            else DTACKn <= 0;
        end
    end
end

// interrupt generation
jtsf_intgen u_intgen(
    .clk        ( clk       ),
    .rst        ( rst       ),
    .cpu_cen    ( cen8      ),
    .V          ( V[7:0]    ),
    .int1       ( int1      ),
    .int2       ( int2      ),
    .inta_n     ( inta_n    ),
    .FC         ( FC        ),
    .ASn        ( ASn       ),
    .dip_pause  ( dip_pause )
);

wire [1:0] dev_br = { 1'b0 /* replace by MCU BR*/, obj_br };
assign bus_ack = ~BGACKn;

jtframe_68kdma #(.BW(2)) u_arbitration(
    .clk        (  clk          ),
    .rst        (  rst          ),
    .cen        ( cen8b         ),
    .cpu_BRn    (  BRn          ),
    .cpu_BGACKn (  BGACKn       ),
    .cpu_BGn    (  BGn          ),
    .cpu_ASn    (  ASn          ),
    .cpu_DTACKn (  DTACKn       ),
    .dev_br     (  dev_br       )
);

fx68k u_cpu(
    .clk        ( clk         ),
    .extReset   ( rst         ),
    .pwrUp      ( rst         ),
    .enPhi1     ( cen8       ),
    .enPhi2     ( cen8b      ),
    .HALTn      ( 1'b1        ),

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
    .BRn        ( BRn         ),
    .BGACKn     ( BGACKn      ),
    .BGn        ( BGn         ),

    .DTACKn     ( DTACKn      ),
    .IPL0n      ( 1'b1        ),
    .IPL1n      ( int1        ),
    .IPL2n      ( int2        ),

    // Unused
    .oRESETn    (             ),
    .oHALTEDn   (             ),
    .VMAn       (             ),
    .E          (             )
);

// `ifdef SIMULATION
//     wire sdram_error;
//
//     jtframe_din_check #(.AW(17)) u_sdram_check(
//         .rst        ( rst           ),
//         .clk        ( clk           ),
//         .cen        ( cpu_cen       ),
//         .rom_cs     (  rom_cs       ),
//         .rom_ok     ( rom_ok        ),
//         .rom_addr   (  rom_addr     ),
//         .rom_data   (  rom_data     ),
//         .error      ( sdram_error   )
//     );
// `endif

endmodule

module jtsf_intgen(
    input           clk,
    input           rst,
    input           cpu_cen,
    input     [7:0] V,
    input     [2:0] FC,
    input           ASn,
    input           dip_pause,

    output          int1,
    output          int2,
    output          inta_n
);

reg  int_n, int_rqb, int_rqb_last;
wire int_rqb_edge;

assign inta_n       = ~&{ FC[2], FC[1], FC[0], ~ASn }; // interrupt ack.
assign int2         = 1;
assign int1         = int_n;
assign int_rqb_edge = int_rqb && !int_rqb_last;  // based on Side Arms: Pos edge

always @(posedge clk)
    if(rst) begin
        int_n <= 1'b1;
    end else if(cpu_cen) begin
        int_rqb_last <= int_rqb;
        if( V==8'h6F || V==8'hEF ) int_rqb <= 0;
        if( V==8'h70 || V==8'hF0 ) int_rqb <= 1;
        if( !inta_n )
            int_n <= 1'b1;
        else
            if ( int_rqb_edge && dip_pause ) int_n <= 0;
    end

endmodule