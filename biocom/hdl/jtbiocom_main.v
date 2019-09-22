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
    output  [12:0]     cpu_AB,
    output  [15:0]     oram_dout,
    input   [ 8:0]     obj_AB,
    output             RnW,
    output  reg        OKOUT,
    output  reg        dmaon,
    input              bus_req,  // Request bus
    output             bus_ack,  // bus acknowledge
    input              blcnten,  // bus line counter enable
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
wire t80_rst_n;
reg  in_cs, ram_cs, misc_cs, scrpos_cs, snd_latch_cs, obj_cs;
reg  scrpt_cs, io_cs;
reg  scr1hpos_cs, scr2hpos_cs, scr1vpos_cs, scr2vpos_cs;
wire wr_n = RnW;
wire ASn;

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
    dmaon         = 1'b0;

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
                                3'd3: OKOUT = 1'b1;
                                3'd5: dmaon = 1'b1; // to MCU
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
wire [12:0] RAM_addr   = blcnten ? {4'b1111, obj_AB} : cpu_AB;
wire        cpu_ram_we = ram_cs && !wr_n;
wire        RAM_we     = blcnten ? 1'b0 : cpu_ram_we;

jtgng_ram #(.aw(13),.cen_rd(0)) u_ramu(
    .clk        ( clk              ),
    .cen        ( cpu_cen          ),
    .addr       ( A[13:1]          ),
    .data       ( cpu_dout[15:8]   ),
    .we         ( ram_cs & !UDSWRn ),
    .q          ( wram_dout[15:8]  )
);

jtgng_ram #(.aw(13),.cen_rd(0)) u_raml(
    .clk        ( clk              ),
    .cen        ( cpu_cen          ),
    .addr       ( A[13:1]          ),
    .data       ( cpu_dout[7:0]    ),
    .we         ( ram_cs & !LDSWRn ),
    .q          ( wram_dout[7:0]   )
);

/////////////////////////////////////////////////////
// Object RAM, 4kB
assign cpu_AB = A[12:0];

jtgng_ram #(.aw(11),.cen_rd(0)) u_obj_ramu(
    .clk        ( clk              ),
    .cen        ( cpu_cen          ),
    .addr       ( A[11:1]          ),
    .data       ( cpu_dout[15:8]   ),
    .we         ( obj_cs & !UDSWRn ),
    .q          ( oram_dout[15:8]  )
);

jtgng_ram #(.aw(11),.cen_rd(0)) u_obj_raml(
    .clk        ( clk              ),
    .cen        ( cpu_cen          ),
    .addr       ( A[11:1]          ),
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

/////////////////////////////////////////////////////////////////
// wait_n generation
wire wait_n;

jtframe_z80wait #(2) u_wait(
    .rst_n      ( t80_rst_n ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    // manage access to shared memory
    .dev_busy   ( { scr_busy, char_busy } ),
    // manage access to ROM data from SDRAM
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),

    .wait_n     ( wait_n    )
);

reg wait_cen;

always @(negedge clk)
    wait_cen <= wait_n;

wire cpu_wait_cen = cpu_cen & wait_cen;

// interrupt generation
reg        int1, int2;
wire [2:0] FC;
wire inta_n = ~&{ FC[2], FC[1], FC[0], ~ASn }; // interrupt ack.

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
    .VPAn       ( VPAn        ),
    .FC0        ( FC[0]       ),
    .FC1        ( FC[1]       ),
    .FC2        ( FC[2]       ),

    .BERRn      ( BERRn       ),
    .BRn        ( BRn         ),
    .BGACKn     ( BGACKn      ),

    .DTACKn     ( DTACKn      ),
    .IPL0n      ( 1'b1        ),
    .IPL1n      ( int1        ),
    .IPL2n      ( int2        ),

    // Unused
    .oRESETn    (             ),
    .oHALTEDn   (             ),
    .VMAn       (             ),
    .BGn        (             ),
    .E          (             )
);

endmodule // jtgng_main