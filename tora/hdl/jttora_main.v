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
    Date: 12-10-2019 */

// Bionic Commando: Main CPU

`timescale 1ns/1ps

module jttora_main(
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
    output reg [15:0]  scr_hpos,
    output reg [15:0]  scr_vpos,
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
reg         scrhpos_cs, scrvpos_cs;
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
    OKOUT         = 1'b0;
    mcu_DMAONn    = 1'b1;   // for once, I leave the original active low setting
    scrvpos_cs   = 1'b0;
    scrhpos_cs   = 1'b0;

    BERRn         = 1'b1;
    // address decoder is not shared with MCU contrary to the original design
    if( CPUbus ) case(A[19:18])
            2'd0: rom_cs = 1'b1;
            2'd1, 2'd2: BERRn = ASn;
            2'd3: if(A[17]) case(A[16:14])  // 111X
                    3'd0:   obj_cs  = 1'b1; // E_0000 
                    3'd1:   io_cs   = 1'b1; // E_4000
                    3'd2: if( !UDSWn && !LDSWn && !A[4]) begin // E_8000
                        // scrpt_cs
                        $display("SCRPTn");
                        case( A[3:1]) // SCRPTn in the schematics
                                3'd0: scrhpos_cs = 1'b1;
                                3'd1: scrvpos_cs = 1'b1;
                                3'd7: begin
                                    OKOUT       = 1'b1;
                                    $display("OKOUT");
                                end
                            default:;
                        endcase
                    end
                    3'd3:   char_cs = 1'b1; // E_C000
                    3'd6:   col_cs  = 1'b1; // F_8000
                    3'd7:   ram_cs  = 1'b1; // F_C000
                endcase
        endcase
end

// SCROLL H/V POSITION
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scr_hpos <= 10'd0;
        scr_vpos <= 10'd0;
    end else if(cpu_cen) begin
        if( scrhpos_cs && !RnW) scr_hpos <= cpu_dout;
        if( scrvpos_cs && !RnW) scr_vpos <= cpu_dout;
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

/////////////////////////////////////////////////////
// RAMs data input mux
reg [7:0] ram_udin, ram_ldin;

always @(*) begin
    ram_udin = cpu_dout[15:8];
    ram_ldin = cpu_dout[ 7:0];
end

/////////////////////////////////////////////////////
// Work RAM, 16kB
reg [13:1]  work_A;
reg         work_uwe, work_lwe;
wire        ram_cen=cpu_cen;

always @(*) begin
    // CPU access
    work_A   = A[13:1];
    work_uwe = ram_cs & !UDSWn;
    work_lwe = ram_cs & !LDSWn;
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
    if( blcnten) begin // Object DMA
        oram_addr = obj_AB[11:1];
        obj_uwe   = 1'b0;
        obj_lwe   = 1'b0;
    end else begin
        oram_addr = A[11:1];
        obj_uwe   = obj_cs & !UDSWn;
        obj_lwe   = obj_cs & !LDSWn;
    end
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

// Cabinet input
reg [15:0] cabinet_input;

always @(posedge clk) if(cpu_cen) begin
    cabinet_input <= A[1] ?
        { dipsw_a, dipsw_b } :
        { coin_input[0], coin_input[1],        // COINS
          start_button[0], start_button[1],    // START
          { joystick1[3:0], joystick1[5:4]},   //  2 buttons
          { joystick2[3:0], joystick2[5:4]} };
end

// Data bus input
reg  [15:0] cpu_din;
reg  [ 7:0] video_dout;
reg  [15:0] owram_dout;
wire        owram_cs = obj_cs | ram_cs;

always @(posedge clk) begin
    owram_dout <= obj_cs ? oram_dout : wram_dout;
end

always @(*)
    case( {owram_cs, video_cs, io_cs} )
        3'b100:  cpu_din = owram_dout;
        3'b010:  cpu_din = { 8'hff, char_dout };
        3'b001:  cpu_din = cabinet_input;
        default: cpu_din = rom_data;
    endcase

assign rom_addr = A[17:1];

// DTACKn generation
wire       inta_n;
wire       bus_cs =   |{ rom_cs, char_cs };
wire       bus_busy = |{ rom_cs & ~rom_ok, char_busy };
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
            if( !LVBL && last_LVBL ) int2 <= 1'b0;
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
        BRn <= ~obj_br; // obj_br is active high
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