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
    output             cpu_cen,
    // Timing
    output  reg        flip,
    input   [8:0]      V,
    input              LHBL,
    input              LVBL,
    // Sound
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
    output reg [9:0]   scr1_hpos,
    output reg [9:0]   scr1_vpos,
    output reg [8:0]   scr2_hpos,
    output reg [8:0]   scr2_vpos,
    // cabinet I/O
    input   [5:0]      joystick1,
    input   [5:0]      joystick2,
    input   [1:0]      start_button,
    input   [1:0]      coin_input,
    // BUS sharing
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
    input      [ 7:0]  mcu_dout,
    output reg [ 7:0]  mcu_din,
    input      [16:1]  mcu_addr,
    input              mcu_wr,
    input              mcu_DMAn,
    output  reg        mcu_DMAONn,
    // Palette
    output             col_uw,
    output             col_lw,
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
wire [3:0] ncA;

`ifdef SIMULATION
wire [24:0] A_full = {ncA, A,1'b0};
`endif
wire [15:0] wram_dout;
reg         BRn, BGACKn;
wire        BGn;
reg         io_cs, ram_cs, obj_cs, col_cs;
reg         scr1hpos_cs, scr2hpos_cs, scr1vpos_cs, scr2vpos_cs;
wire        ASn;

wire mreq_n, rfsh_n, busak_n;
assign cpu_cen = cen12;
reg BERRn;

// high during DMA transfer
wire UDSn, LDSn;
wire UDSWn = RnW | UDSn;
wire LDSWn = RnW | LDSn;

assign col_uw = col_cs & ~UDSWn;
assign col_lw = col_cs & ~LDSWn;

wire CPUbus = !blcnten && mcu_DMAn; // main CPU in control of the bus

always @(*) begin
    rom_cs        = 1'b0;
    ram_cs        = 1'b0;
    obj_cs        = 1'b0;
    col_cs        = 1'b0;
    io_cs         = 1'b0;
    char_cs       = 1'b0;
    scr1_cs       = 1'b0;
    scr2_cs       = 1'b0;
    OKOUT         = 1'b0;
    mcu_DMAONn    = 1'b1;   // for once, I leave the original active low setting
    scr1vpos_cs   = 1'b0;
    scr2vpos_cs   = 1'b0;
    scr1hpos_cs   = 1'b0;
    scr2hpos_cs   = 1'b0;

    BERRn         = 1'b1;
    // address decoder is not shared with MCU contrary to the original design
    if( CPUbus ) case(A[19:18])
            2'd0: rom_cs = 1'b1;
            2'd1, 2'd2: BERRn = ASn;
            2'd3: if(A[17]) case(A[16:14])  // 111X
                    3'd0:   obj_cs  = 1'b1; // E_0000 
                    3'd1:   io_cs   = 1'b1; // E_4000
                    3'd2: if( !UDSWn && !LDSWn && A[4]) begin // E_8010
                        // scrpt_cs
                        $display("SCRPTn");
                        case( A[3:1]) // SCRPTn in the schematics
                                3'd0: scr1hpos_cs = 1'b1;
                                3'd1: scr1vpos_cs = 1'b1;
                                3'd2: scr2hpos_cs = 1'b1;
                                3'd3: scr2vpos_cs = 1'b1;
                                3'd4: begin
                                    OKOUT       = 1'b1;
                                    $display("OKOUT");
                                end
                                3'd5: begin
                                    mcu_DMAONn  = 1'b0; // to MCU
                                    $display("mcu_DOMAONn");
                                end
                            default:;
                        endcase
                    end
                    3'd3:   char_cs = 1'b1; // E_C000
                    3'd4:   scr1_cs = 1'b1; // F_0000
                    3'd5:   scr2_cs = 1'b1; // F_4000
                    3'd6:   col_cs  = 1'b1; // F_8000
                    3'd7:   ram_cs  = 1'b1; // F_C000
                endcase
        endcase
end

// MCU DMA address decoder
reg mcu_obj_cs, mcu_ram_cs, mcu_other_cs;

always @(*) begin
    mcu_obj_cs   = 1'b0;
    mcu_ram_cs   = 1'b0;
    mcu_other_cs = 1'b0;
    if( !mcu_DMAn )
        case(mcu_addr[16:14])
            3'd0:    mcu_obj_cs   = 1'b1;
            3'd7:    mcu_ram_cs   = 1'b1;
            default: mcu_other_cs = 1'b1;
        endcase
end

// SCROLL H/V POSITION
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scr1_hpos <= 10'd0;
        scr1_vpos <= 10'd0;
        scr2_hpos <= 9'd0;
        scr2_vpos <= 9'd0;
    end else if(cpu_cen) begin
        if( scr1hpos_cs && !RnW) scr1_hpos <= cpu_dout[9:0];
        if( scr1vpos_cs && !RnW) scr1_vpos <= cpu_dout[9:0];
        if( scr2hpos_cs && !RnW) scr2_hpos <= cpu_dout[8:0];
        if( scr2vpos_cs && !RnW) scr2_vpos <= cpu_dout[8:0];
    end
end

// special registers
always @(posedge clk)
    if( rst ) begin
        flip         <= 1'b0;
        snd_latch    <= 8'b0;
    end
    else if(cpu_cen) begin
        if( !UDSWn && io_cs)
            case( { A[1]} )
                1'b0: flip      <= cpu_dout[8];
                1'b1: snd_latch <= cpu_dout[7:0];
            endcase
    end

reg [15:0] cabinet_input;

always @(posedge clk) if(cpu_cen) begin
    cabinet_input <= A[1] ?
        { dipsw_a, dipsw_b } :
        { coin_input[0], coin_input[1],        // COINS
          start_button[0], start_button[1],    // START
          { joystick1[3:0], joystick1[5:4]},   //  2 buttons
          { joystick2[3:0], joystick2[5:4]} };
end

/////////////////////////////////////////////////////
// RAMs data input mux
reg [7:0] ram_udin, ram_ldin;

always @(*) begin
    if( !mcu_DMAn ) begin
        ram_udin = 8'hff;       // unused
        ram_ldin = mcu_dout;
    end else begin
        ram_udin = cpu_dout[15:8];
        ram_ldin = cpu_dout[ 7:0];
    end
end

/////////////////////////////////////////////////////
// MCU DMA data output mux
always @(*) begin
    if( mcu_obj_cs )
        mcu_din = oram_dout[7:0];
    else
        mcu_din = wram_dout[7:0];
end

/////////////////////////////////////////////////////
// Work RAM, 16kB
reg [13:1]  work_A;
reg         work_uwe, work_lwe;
wire        ram_cen=cpu_cen;

always @(*) begin
    if( mcu_ram_cs ) begin
        // MCU access
        work_A   = mcu_addr[13:1];
        work_uwe = 1'b0;
        work_lwe = mcu_wr ;
    end else begin 
        // CPU access
        work_A   = A[13:1];
        work_uwe = ram_cs & !UDSWn;
        work_lwe = ram_cs & !LDSWn;
    end
end

jtgng_ram #(.aw(13),.cen_rd(0)) u_ramu(
    .clk        ( clk              ),
    .cen        ( ram_cen          ),
    .addr       ( work_A           ),
    .data       ( ram_udin         ),
    .we         ( work_uwe         ),
    .q          ( wram_dout[15:8]  )
);

jtgng_ram #(.aw(13),.cen_rd(0)) u_raml(
    .clk        ( clk              ),
    .cen        ( ram_cen          ),
    .addr       ( work_A           ),
    .data       ( ram_ldin         ),
    .we         ( work_lwe         ),
    .q          ( wram_dout[7:0]   )
);

/////////////////////////////////////////////////////
// Object RAM, 4kB
assign cpu_AB = A[13:1];
reg [10:0] oram_addr;
reg  obj_uwe, obj_lwe;

always @(*) begin    
    case( {blcnten, mcu_obj_cs} )
        2'b10: begin // Object DMA
            oram_addr = obj_AB[11:1];
            obj_uwe   = 1'b0;
            obj_lwe   = 1'b0;
        end
        2'b01: begin // MCU DMA
            oram_addr = mcu_addr[11:1];
            obj_uwe   = 1'b0;
            obj_lwe   = mcu_wr ;
        end
        default: begin
            oram_addr = A[11:1];
            obj_uwe   = obj_cs & !UDSWn;
            obj_lwe   = obj_cs & !LDSWn;
        end
    endcase
end

jtgng_ram #(.aw(11),.cen_rd(0)) u_obj_ramu(
    .clk        ( clk              ),
    .cen        ( ram_cen          ),
    .addr       ( oram_addr        ),
    .data       ( ram_udin         ),
    .we         ( obj_uwe          ),
    .q          ( oram_dout[15:8]  )
);

jtgng_ram #(.aw(11),.cen_rd(0)) u_obj_raml(
    .clk        ( clk              ),
    .cen        ( ram_cen          ),
    .addr       ( oram_addr        ),
    .data       ( ram_ldin         ),
    .we         ( obj_lwe          ),
    .q          ( oram_dout[7:0]   )
);


// Data bus input
reg  [15:0] cpu_din;
reg  [ 7:0] video_dout;
wire        video_cs = char_cs | scr2_cs | scr1_cs;
reg  [15:0] owram_dout;
wire        owram_cs = obj_cs | ram_cs;

always @(posedge clk) begin
    case( {scr2_cs, scr1_cs} )
        2'b10:   video_dout <= scr2_dout;
        2'b01:   video_dout <= scr1_dout;
        default: video_dout <= char_dout;
    endcase
    owram_dout <= obj_cs ? oram_dout : wram_dout;
end

always @(*)
    case( {owram_cs, video_cs, io_cs} )
        3'b100:  cpu_din = owram_dout;
        3'b010:  cpu_din = { 8'hff, video_dout };
        3'b001:  cpu_din = cabinet_input;
        default: cpu_din = rom_data;
    endcase

assign rom_addr = A[17:1];

// DTACKn generation

// wire dtack_cln = ~|{ ASn, |{char_cs, scr1_cs, scr2_cs} };
// wire [3:0] dtack_q;
// wire       dtack_ca;
wire       inta_n;
//wire DTACKn =  |{ dtack_ca, scr1_busy, scr2_busy, char_busy };
//wire DTACKn =  |{ (rom_cs&~rom_ok), scr1_busy, scr2_busy, char_busy };
wire       bus_cs =   |{ rom_cs, scr1_cs, scr2_cs, char_cs };
wire       bus_busy = |{ rom_cs & ~rom_ok, scr1_busy, scr2_busy, char_busy };
reg DTACKn;
always @(posedge clk, posedge rst) begin : dtack_gen
    reg       last_ASn;
    if( rst ) begin
        DTACKn <= 1'b1;
    end else if(cpu_cen) begin
        DTACKn   <= 1'b1;
        last_ASn <= ASn;
        if( !ASn  ) begin
            if( bus_cs ) begin
                if (!bus_busy) DTACKn <= 1'b0;
            end
            else DTACKn <= 1'b0;
        end
        if( ASn && !last_ASn ) DTACKn <= 1'b1;
    end
end 

// jt74161 u_dtack(
//     .clk    ( clk                      ),
//     .cl_b   ( dtack_cln                ),
//     .cet    (   inta_n & (rom_cs ? rom_ok : 1'b1)        ),
//     .cep    ( DTACKn                   ),
//     .d      ( { 1'b1, ~rom_cs, 2'b11 } ),
//     .q      ( dtack_q                  ),
//     .ld_b   ( dtack_q[3]               ),
//     .ca     ( dtack_ca                 )
// );
// 
// interrupt generation
reg        int1, int2;
wire [2:0] FC;
assign inta_n = ~&{ FC[2], FC[1], FC[0], ~ASn }; // interrupt ack.

always @(posedge clk, posedge rst) begin : int_gen
    reg last_LVBL, last_V256;
    if( rst ) begin
        int1 <= 1'b1;
        int2 <= 1'b1;
    end else begin
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
end

// Original design uses HALT signal instead of BR/BG/BGACK triad
// but fx68k does not support it, so HALT operation is implemented
// through regular bus arbitrion

reg bus_dma;

assign bus_ack = bus_dma;

always @(posedge clk, posedge rst)
    if( rst ) begin
        BRn     <= 1'b1;
        BGACKn  <= 1'b1;
        bus_dma <= 1'b0;
    end else begin
        case( bus_dma )
            1'b0: begin
                if( !BRn && !BGn ) begin
                    bus_dma <= 1'b1;
                    BGACKn  <= 1'b0;
                end
            end
            1'b1: begin
                if( BRn ) begin
                    bus_dma <= 1'b1;
                end
                BGACKn <= BGn;
            end
        endcase
        BRn <= ~(~mcu_brn | obj_br); // obj_br is active high
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

endmodule
/*
// synchronous presettable 4-bit binary counter, asynchronous clear
module jt74161( // ref: 74??161
    input            cet,   // pin: 10
    input            cep,   // pin: 7
    input            ld_b,  // pin: 9
    input            clk,   // pin: 2
    input            cl_b,  // pin: 1
    input      [3:0] d,     // pin: 6,5,4,3
    output reg [3:0] q,     // pin: 11,12,13,14
    output           ca     // pin: 15
 );

    `ifdef SIMULATION
    initial q=4'd0;
    `endif

    assign ca = &{q, cet};

    always @(posedge clk or negedge cl_b)
        if( !cl_b )
            q <= 4'd0;
        else begin
            if(!ld_b) q <= d;
            else if( cep&&cet ) q <= q+4'd1;
        end

endmodule // jt74161
*/