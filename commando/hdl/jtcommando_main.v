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
    Date: 2-7-2019 */

// commando: Main CPU

`timescale 1ns/1ps

module jtcommando_main(
    input              rst,
    input              clk,
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
    output  reg        sres_b, // sound reset
    output  reg        snd_int,
    output  reg  [7:0] snd_latch,
    // Characters
    input        [7:0] char_dout,
    output       [7:0] cpu_dout,
    output  reg        char_cs,
    input              char_busy,
    // scroll
    input   [7:0]      scr_dout,
    output  reg        scr_cs,
    input              scr_busy,
    output reg [8:0]   scr_hpos,
    output reg [8:0]   scr_vpos,
    // cabinet I/O
    input   [5:0]      joystick1,
    input   [5:0]      joystick2,
    input   [1:0]      start_button,
    input   [1:0]      coin_input,
    // BUS sharing
    output  [12:0]     cpu_AB,
    output  [ 7:0]     ram_dout,
    input   [ 8:0]     obj_AB,
    output             RnW,
    output  reg        OKOUT,
    input              bus_req,  // Request bus
    output             bus_ack,  // bus acknowledge
    input              blcnten,  // bus line counter enable
    // ROM access
    output  reg        rom_cs,
    output      [15:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,
    // PROM 6L (interrupts)
    input    [7:0]     prog_addr,
    input              prom_6l_we,
    input    [3:0]     prog_din,
    // DIP switches
    input              dip_pause,
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b
);

wire [15:0] A;
wire t80_rst_n;
reg in_cs, ram_cs, misc_cs, scrpos_cs, snd_latch_cs;
reg SECWR_cs;
wire rd_n, wr_n;

assign RnW = wr_n;

wire mreq_n, rfsh_n, busak_n;
assign cpu_cen = cen3;
// `ifdef  MIST
// assign cpu_cen = cen3; // MiST cannot use internal BRAM for CPU ROM. 
// // In order to cope with the slow down problems
// // of the SDRAM access, I have to increase the CPU speed. 
// // Otherwise, graphic glitches occur in the scroll and character layers.
// `else
// // MiSTer and other platforms that can have no-delay reads for CPU ROM
// // can use the original CPU speed
// assign cpu_cen = cen3;
// `endif
assign bus_ack = ~busak_n;

always @(*) begin
    rom_cs        = 1'b0;
    ram_cs        = 1'b0;
    snd_latch_cs  = 1'b0;
    misc_cs       = 1'b0;
    in_cs         = 1'b0;
    char_cs       = 1'b0;
    scr_cs        = 1'b0;
    scrpos_cs     = 1'b0;
    OKOUT         = 1'b0;
    if( rfsh_n && !mreq_n ) casez(A[15:13])
        3'b0??,3'b10?: rom_cs = 1'b1; // 48 kB
        3'b110: // CXXX, DXXX
            case(A[12:11])
                2'b00: // C0
                    in_cs = 1'b1;
                2'b01: // C8
                    casez(A[3:0])
                        4'b0_000: snd_latch_cs = 1'b1;
                        4'b0_100: misc_cs      = 1'b1;
                        4'b0_110: OKOUT        = 1'b1;
                        4'b1_???: scrpos_cs    = 1'b1;  // C808-C80F
                        default:;
                    endcase
                2'b10: // D0
                    char_cs = 1'b1; // D0CS
                2'b11: // D8
                    scr_cs = 1'b1;
            endcase
        3'b111: ram_cs = 1'b1;
    endcase
end

// SCROLL H/V POSITION
always @(posedge clk, negedge t80_rst_n) begin
    if( !t80_rst_n ) begin
        scr_hpos <= 9'd0;
        scr_vpos <= 9'd0;
    end else if(cpu_cen) begin
        if( scrpos_cs && A[3])
        case(A[1:0])
            2'd0: scr_hpos[7:0] <= cpu_dout;
            2'd1: scr_hpos[8]   <= cpu_dout[0];
            2'd2: scr_vpos[7:0] <= cpu_dout;
            2'd3: scr_vpos[8]   <= cpu_dout[0];
        endcase
    end
end

// special registers
always @(posedge clk)
    if( rst ) begin
        flip      <= 1'b0;
        sres_b    <= 1'b1;
    end
    else if(cpu_cen) begin
        if( misc_cs  && !wr_n ) begin
            flip     <= cpu_dout[7];
            sres_b   <= ~cpu_dout[4]; // inverted through NPN
        end
        if( snd_latch_cs && !wr_n ) begin
            snd_latch <= cpu_dout;
        end
    end

jt12_rst u_rst(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .rst_n  ( t80_rst_n )
);

reg [7:0] cabinet_input;

always @(*)
    case( A[2:0] )
        3'd0: cabinet_input = { coin_input, // COINS
                     2'b11, // undocumented. D5 & D4 what are those?
                     1'b1,
                     1'b1,
                     start_button }; // START
        3'd1: cabinet_input = { 2'b1, joystick1 };
        3'd2: cabinet_input = { 2'b1, joystick2 };
        3'd3: cabinet_input = dipsw_a;
        3'd4: cabinet_input = dipsw_b;
        default: cabinet_input = 8'hff;
    endcase


// RAM, 16kB
wire cpu_ram_we = ram_cs && !wr_n;
assign cpu_AB = A[12:0];

wire [12:0] RAM_addr = blcnten ? {4'b1111, obj_AB} : cpu_AB;
wire RAM_we   = blcnten ? 1'b0 : cpu_ram_we;

jtgng_ram #(.aw(13),.cen_rd(0)) RAM(
    .clk        ( clk       ),
    .cen        ( cpu_cen   ),
    .addr       ( RAM_addr  ),
    .data       ( cpu_dout  ),
    .we         ( RAM_we    ),
    .q          ( ram_dout  )
);

// Data bus input
reg [7:0] cpu_din;
wire [3:0] int_ctrl;
wire iorq_n, m1_n;
wire irq_ack = !iorq_n && !m1_n;
wire [7:0] irq_vector = {3'b110, int_ctrl[1:0], 3'b111 }; // Schematic K11

`ifndef TESTROM
// OP-code bits are shuffled
wire [7:0] rom_opcode = A==16'd0 ? rom_data : 
    {rom_data[3:1], rom_data[4], rom_data[7:5], rom_data[0] };
`else 
wire [7:0] rom_opcode = rom_data; // do not decrypt test ROMs
`endif

always @(*)
    if( irq_ack ) // Interrupt address
        cpu_din = irq_vector;
    else
    case( {ram_cs, char_cs, scr_cs, rom_cs, in_cs} )
        5'b100_00: cpu_din = // (cheat_invincible && (A==16'hf206 || A==16'hf286)) ? 8'h40 :
                            ram_dout;
        5'b010_00: cpu_din = char_dout;
        5'b001_00: cpu_din = scr_dout;
        5'b000_10: cpu_din = !m1_n ? rom_opcode : rom_data;
        5'b000_01: cpu_din = cabinet_input;
        default:  cpu_din = rom_data;
    endcase

assign rom_addr = A;

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

jtgng_prom #(.aw(8),.dw(4),.simfile("../../../rom/commando/vtb5.6l")) u_vprom(
    .clk    ( clk          ),
    .cen    ( cen6         ),
    .data   ( prog_din     ),
    .wr_addr( prog_addr    ),
    .rd_addr( V[7:0]       ),
    .we     ( prom_6l_we   ),
    .q      ( int_ctrl     )
);

// interrupt generation
reg int_n;
reg LHBL_posedge, H1_posedge;

always @(posedge clk) begin : LHBL_edge
    reg LHBL_old, H1_old;
    LHBL_old<=LHBL;
    LHBL_posedge <= !LHBL_old && LHBL;

    H1_old <= H1;
    H1_posedge <= !H1_old && H1;
end

reg pre_int;
always @(posedge clk) begin
    if( irq_ack )
        pre_int <= 1'b0;
    else if( LHBL_posedge ) pre_int <= int_ctrl[3];
end

always @(posedge clk) begin : irq_gen
    reg pre_int2;
    reg last2;
    if (rst) begin
        snd_int <= 1'b1;
        int_n   <= 1'b1;
    end else begin
        last2 <= pre_int2;
        if( H1_posedge ) begin
            // Schematic 7L - sound interrupter
            snd_int  <= int_ctrl[2];
            pre_int2 <= pre_int;
        end
        if( irq_ack )
            int_n <= 1'b1;
        else if( pre_int2 && !last2 ) int_n <= 1'b0;
    end
end

jtframe_z80 u_cpu(
    .rst_n      ( t80_rst_n   ),
    .clk        ( clk         ),
    .cen        ( cpu_wait_cen),
    .wait_n     ( 1'b1        ),
    .int_n      ( int_n       ),
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( ~bus_req    ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    ( busak_n     ),
    .A          ( A           ),
    .din        ( cpu_din     ),
    .dout       ( cpu_dout    )
);
endmodule // jtgng_main