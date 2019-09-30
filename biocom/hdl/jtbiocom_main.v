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
    Date: 12-9-2019 */

// Bionic Commando: Main CPU

`timescale 1ns/1ps

module jtbiocom_main(
    input              rst,
    input              clk,
    input              cen12,
    input              cen12b,
    input              cen6,   // 6MHz
    input              cen3    /* synthesis direct_enable = 1 */,   // 3MHz
    output             cpu_cen,
    // Timing
    output  reg        flip,
    input   [8:0]      V,
    input              LHBL,
    input              LVBL,
    input              H1,
    // Sound
    output  reg        snd_int,
    output  reg  [7:0] snd_latch,
    // Characters
    input        [7:0] char_dout,
    output      [15:0] cpu_dout,
    output  reg        char_cs,
    input              char_busy,
    // scroll
    input   [7:0]      scr1_dout,
    input   [7:0]      scr2_dout,
    output  reg        scr1_cs,
    output  reg        scr2_cs,
    input              scr1_busy,
    input              scr2_busy,
    output reg [8:0]   scr1_hpos,
    output reg [8:0]   scr1_vpos,
    output reg [8:0]   scr2_hpos,
    output reg [8:0]   scr2_vpos,
    // cabinet I/O
    input   [5:0]      joystick1,
    input   [5:0]      joystick2,
    input   [1:0]      start_button,
    input   [1:0]      coin_input,
    // BUS sharing
    input              dma,
    output  [13:1]     cpu_AB,
    output  [15:0]     oram_dout,
    input   [13:1]     obj_AB,
    output             RnW,
    output  reg        OKOUT,
    input              obj_br,   // Request bus
    output             bus_ack,  // bus acknowledge
    input              blcnten,  // bus line counter enable
    // MCU interface
    input              mcu_brn,
    input   [ 7:0]     mcu2main_din,
    output  [ 7:0]     mcu2main_dout,
    input   [16:1]     mcu2main_addr,
    input              mcu2main_wrn,
    input              mcu_DMAn,
    output  reg        mcu_DMAONn,
    // Palette
    output             coluw,    // all active high
    output             collw,    // all active high
    output             colwr,    // all active high
    output  reg        col_cs,
    // ROM access
    output  reg        rom_cs,
    output      [17:1] rom_addr,
    input       [15:0] rom_data,
    input              rom_ok,
    // DIP switches
    input              dip_pause,
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b
);

wire [19:1] A;
wire [15:0] wram_dout;
reg         BRn, BGACKn;
wire        BGn;
reg         in_cs, ram_cs, misc_cs, scrpos_cs, snd_latch_cs, obj_cs;
reg         scrpt_cs, io_cs;
reg         scr1hpos_cs, scr2hpos_cs, scr1vpos_cs, scr2vpos_cs;
wire        wr_n = RnW;
wire        ASn;

wire mreq_n, rfsh_n, busak_n;
assign cpu_cen = cen12;
reg BERRn;

// high during DMA transfer
wire UDSn, LDSn;
wire UDSWn = RnW | UDSn;
wire LDSWn = RnW | LDSn;
wire blcntenq = blcnten | dma;
wire UDSWRn   = UDSWn | blcntenq;
wire LDSWRn   = LDSWn | blcntenq;

always @(*) begin
    rom_cs        = 1'b0;
    ram_cs        = 1'b0;
    obj_cs        = 1'b0;
    col_cs        = 1'b0;
    io_cs         = 1'b0;
    char_cs       = 1'b0;
    scr1_cs       = 1'b0;
    scr2_cs       = 1'b0;
    scrpt_cs      = 1'b0;
    OKOUT         = 1'b0;
    mcu_DMAONn    = 1'b1;   // for once, I leave the original active low setting

    BERRn         = 1'b1;
    if( blcnten ) case(A[19:18])
            2'd0: rom_cs = 1'b1;
            2'd1, 2'd2: BERRn = ASn;
            2'd3: if(A[17]) case(A[16:14])
                    3'd0:   obj_cs  = 1'b1;
                    3'd1:   begin
                        io_cs    = 1'b1;

                    end
                    3'd2:   if( !UDSWRn && !LDSWRn && A[4]) case( A[3:1]) // SCRPTn in the schematics
                                3'd0: scr1hpos_cs = 1'b1;
                                3'd1: scr1vpos_cs = 1'b1;
                                3'd2: scr2hpos_cs = 1'b1;
                                3'd3: scr2vpos_cs = 1'b1;
                                3'd3: OKOUT       = 1'b1;
                                3'd5: mcu_DMAONn  = 1'b0; // to MCU
                            default:;
                        endcase
                    3'd3:   char_cs = 1'b1;
                    3'd4:   scr1_cs = 1'b1;
                    3'd5:   scr2_cs = 1'b1;
                    3'd6:   col_cs  = !wr_n;
                    3'd7:   ram_cs  = 1'b1;
                endcase
        endcase
end

// SCROLL H/V POSITION
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scr1_hpos <= 9'd0;
        scr1_vpos <= 9'd0;
        scr2_hpos <= 9'd0;
        scr2_vpos <= 9'd0;
    end else if(cpu_cen) begin
        if( scr1hpos_cs ) scr1_hpos <= cpu_dout[8:0];
        if( scr2hpos_cs ) scr2_hpos <= cpu_dout[8:0];
        if( scr1vpos_cs ) scr1_vpos <= cpu_dout[8:0];
        if( scr2vpos_cs ) scr2_vpos <= cpu_dout[8:0];
    end
end

// special registers
always @(posedge clk)
    if( rst ) begin
        flip         <= 1'b0;
        snd_latch    <= 8'b0;
    end
    else if(cpu_cen) begin
        if( io_cs  && !UDSWn ) begin
            if( !A[1] && UDSn )
                flip <= cpu_dout[8];
            else
                snd_latch <= cpu_dout[7:0];
        end
    end

wire [15:0] cabinet_input = A[1] ?
      { dipsw_a, dipsw_b } :
      { coin_input,      // COINS
        start_button,    // START
        joystick1[5:0],  //  2 buttons
        joystick2[5:0] };


/////////////////////////////////////////////////////
// Work RAM, 16kB
wire        cpu_ram_we = ram_cs && !wr_n;
reg [13:1]  work_A;
reg         work_uwe, work_lwe;
assign      mcu2main_dout = wram_dout[7:0];

always @(*) begin
    if( !mcu_brn && !BGn && mcu2main_addr[16:14]==3'b111 ) begin
        // MCU access
        work_A   = mcu2main_addr[13:1];
        work_uwe = 1'b0;
        work_lwe = !mcu2main_wrn;
    end else begin 
        // CPU access
        work_A   = A[13:1];
        work_uwe = ram_cs & !UDSWRn;
        work_lwe = ram_cs & !LDSWRn;
    end
end

jtgng_ram #(.aw(13),.cen_rd(0)) u_ramu(
    .clk        ( clk              ),
    .cen        ( cpu_cen          ),
    .addr       ( A[13:1]          ),
    .data       ( cpu_dout[15:8]   ),
    .we         ( work_uwe         ),
    .q          ( wram_dout[15:8]  )
);

jtgng_ram #(.aw(13),.cen_rd(0)) u_raml(
    .clk        ( clk              ),
    .cen        ( cpu_cen          ),
    .addr       ( A[13:1]          ),
    .data       ( cpu_dout[7:0]    ),
    .we         ( work_lwe         ),
    .q          ( wram_dout[7:0]   )
);

/////////////////////////////////////////////////////
// Object RAM, 4kB
assign cpu_AB = A[13:1];
wire [10:0] oram_addr   = blcnten ? obj_AB[11:1] : A[11:1];

jtgng_ram #(.aw(11),.cen_rd(0)) u_obj_ramu(
    .clk        ( clk              ),
    .cen        ( cpu_cen          ),
    .addr       ( oram_addr        ),
    .data       ( cpu_dout[15:8]   ),
    .we         ( obj_cs & !UDSWRn ),
    .q          ( oram_dout[15:8]  )
);

jtgng_ram #(.aw(11),.cen_rd(0)) u_obj_raml(
    .clk        ( clk              ),
    .cen        ( cpu_cen          ),
    .addr       ( oram_addr        ),
    .data       ( cpu_dout[7:0]    ),
    .we         ( obj_cs & !LDSWRn ),
    .q          ( oram_dout[7:0]   )
);


// Data bus input
reg  [15:0] cpu_din;
wire iorq_n, m1_n;
wire irq_ack = !iorq_n && !m1_n;

`ifndef TESTROM
// OP-code bits are shuffled
wire [7:0] rom_opcode = A==16'd0 ? rom_data : 
    {rom_data[3:1], rom_data[4], rom_data[7:5], rom_data[0] };
`else 
wire [7:0] rom_opcode = rom_data; // do not decrypt test ROMs
`endif

always @(*)
    case( {ram_cs, char_cs, scr2_cs, scr1_cs, rom_cs, in_cs} )
        6'b100_000: cpu_din = wram_dout;
        6'b010_000: cpu_din = { 8'hff, char_dout };
        6'b001_000: cpu_din = { 8'hff, scr2_dout };
        6'b000_100: cpu_din = { 8'hff, scr1_dout };
        6'b000_010: cpu_din = rom_data;
        6'b000_001: cpu_din = cabinet_input;
        default:    cpu_din = rom_data;
    endcase

assign rom_addr = A[17:1];

// DTACKn generation

wire dtack_cln = ~|{ ASn, |{char_cs, scr1_cs, scr2_cs} };
wire [3:0] dtack_q;
wire       dtack_ca;
wire       inta_n;
wire DTACKn = |{ ~dtack_ca, scr1_busy, scr2_busy, char_busy };

jt74161 u_dtack(
    .cl_b   ( dtack_cln                ),
    .cet    (   inta_n                 ),
    .cep    ( DTACKn                   ),
    .d      ( { 1'b1, ~rom_cs, 2'b11 } ),
    .q      ( dtack_q                  ),
    .ld_b   ( dtack_q[3]               ),
    .ca     ( dtack_ca                 )
);

// interrupt generation
reg        int1, int2;
wire [2:0] FC;
assign inta_n = ~&{ FC[2], FC[1], FC[0], ~ASn }; // interrupt ack.

always @(posedge clk) begin : int_gen
    reg last_LVBL, last_V256;
    last_LVBL <= LVBL;
    last_V256 <= V[8];

    if( !inta_n ) begin
        int1 <= 1'b1;
        int2 <= 1'b1;
    end
    else begin
        if( V[8] && !last_V256 ) int2 <= 1'b0;
        if( !LVBL && last_LVBL ) int1 <= 1'b0;
    end
end

wire [3:0] ncA;

// Original design uses HALT signal instead of BR/BG/BGACK triad
// but fx68k does not support it, so HALT operation is implemented
// through regular bus arbitrion

always @(posedge clk, posedge rst)
    if( rst ) begin
        BRn    <= 1'b1;
        BGACKn <= 1'b1;
    end else begin
        BGACKn <= BGn;
        BRn <= !mcu_brn || obj_br;
    end

fx68k u_cpu(
    .clk        ( clk         ),
    .extReset   ( rst         ),
    .pwrUp      ( rst         ),
    .enPhi1     ( cen12       ),
    .enPhi2     ( cen12b      ),

    // Buses
    .eab        ( { ncA, A }  ),
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

endmodule // jtgng_main

// synchronous presettable 4-bit binary counter, asynchronous clear
module jt74161( // ref: 74??161
    input            cet,   // pin: 10
    input            cep,   // pin: 7
    input            ld_b,  // pin: 9
    input            clk,   // pin: 2
    input            cl_b,  // pin: 1
    input      [3:0] d,     // pin: 6,5,4,3
    output     [3:0] q,     // pin: 11,12,13,14
    output           ca     // pin: 15
 );

    assign ca = &{q, cet};

    initial qq=4'd0;
    reg [3:0] qq;
    assign q = qq;
    always @(posedge clk or negedge cl_b)
        if( !cl_b )
            qq <= 4'd0;
        else begin
            if(!ld_b) qq <= d;
            else if( cep&&cet ) qq <= qq+4'd1;
        end

endmodule // jt74161