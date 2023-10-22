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
    Date: 18-11-2019 */


module jtbtiger_main(
    input              rst,
    input              clk,
    input              cen6,   // 6MHz
    input              cen3    /* synthesis direct_enable = 1 */,   // 3MHz
    output             cpu_cen,
    // Timing
    output  reg        flip,
    output  reg        blue_cs,
    output  reg        redgreen_cs,
    input   [8:0]      V,
    input              LHBL,
    input              LVBL,
    input              H1,
    // Sound
    output  reg        sres_b, // sound reset
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
    output reg [10:0]  scr_hpos,
    output reg [10:0]  scr_vpos,
    output reg [1:0]   scr_bank,
    output reg         scr_layout,
    output  reg        CHRON,
    output  reg        SCRON,
    output  reg        OBJON,
    // Security
    input      [7:0]   mcu_dout,
    output reg [7:0]   mcu_din,
    output reg         mcu_wr,
    output reg         mcu_rd,
    // cabinet I/O
    input   [5:0]      joystick1,
    input   [5:0]      joystick2,
    input   [1:0]      cab_1p,
    input   [1:0]      coin,
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
    output  reg [18:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,
    // DIP switches
    input              service,
    input              dip_pause,
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b
);

wire [15:0] A;
wire t80_rst_n;
reg in_cs, ram_cs, bank_cs, scrpos_cs, snd_latch_cs;
wire rd_n, wr_n;

assign RnW = wr_n;

wire mreq_n, rfsh_n, busak_n;
assign cpu_cen = cen6;
assign bus_ack = ~busak_n;

reg [7:0] cpu_din;
wire iorq_n, m1_n;
wire irq_ack = !iorq_n && !m1_n;

// Memory map
always @(*) begin
    rom_cs        = 1'b0;
    ram_cs        = 1'b0;
    char_cs       = 1'b0;
    scr_cs        = 1'b0;
    blue_cs       = 1'b0;
    redgreen_cs   = 1'b0;
    if( rfsh_n && !mreq_n ) casez(A[15:13])
        3'b0??: rom_cs = 1'b1;
        3'b10?: rom_cs = 1'b1; // banked ROM
        3'b110: // CXXX, DXXX
            casez(A[12:11])
                2'b0?: // C0
                    scr_cs = 1'b1;
                2'b10: // D0
                    char_cs = 1'b1; // D0CS
                2'b11: // D8
                    if( A[10] )
                        blue_cs     = 1'b1;
                    else
                        redgreen_cs = 1'b1;
                default:;
            endcase
        3'b111: ram_cs = 1'b1; // EXXX, FXXX
    endcase
end

// Port map
reg en_cs, scr_bank_cs, mcu_cs, video_cs, layout_cs;

always @(*) begin
    snd_latch_cs  = 1'b0;
    bank_cs       = 1'b0;
    in_cs         = 1'b0;
    scrpos_cs     = 1'b0;
    en_cs         = 1'b0;
    OKOUT         = 1'b0;
    scr_bank_cs   = 1'b0;
    mcu_cs        = 1'b0;
    video_cs      = 1'b0;
    layout_cs     = 1'b0;
    if( rfsh_n && !iorq_n ) begin
        in_cs  = A[3:0] <= 4'd5 && RnW;
        mcu_cs = A[3:0] == 4'd7;
        if( !RnW ) casez(A[3:0])
                4'd0: snd_latch_cs = 1'b1;
                4'd1: bank_cs      = 1'b1;
                4'd4: video_cs     = 1'b1;
                4'd6: OKOUT        = 1'b1;
                4'd8, 4'd9, 4'd10, 4'd11: scrpos_cs = 1'b1;
                4'd12: en_cs       = 1'b1; // video enable
                4'd13: scr_bank_cs = 1'b1; // BG bank
                4'd14: layout_cs   = 1'b1; // screen alyout
                default:;
            endcase
    end
end

// SCROLL H/V POSITION
always @(posedge clk, negedge t80_rst_n) begin
    if( !t80_rst_n ) begin
        scr_hpos <= 11'd0;
        scr_vpos <= 11'd0;
    end else if(cpu_cen) begin
        if( scrpos_cs )
        case(A[1:0])
            2'd0: scr_hpos[ 7:0] <= cpu_dout;
            2'd1: scr_hpos[10:8] <= cpu_dout[2:0];
            2'd2: scr_vpos[ 7:0] <= cpu_dout;
            2'd3: scr_vpos[10:8] <= cpu_dout[2:0];
        endcase
    end
end

// special registers
reg [3:0] bank;

always @(posedge clk)
    if( rst ) begin
        flip      <= 1'b0;
        sres_b    <= 1'b1;
        bank      <= 4'd0;
        CHRON     <= 1'b1;
        SCRON     <= 1'b1;
        OBJON     <= 1'b1;
        scr_bank  <= 2'b0;
        mcu_wr    <= 1'b0;
        mcu_rd    <= 0;
        scr_layout<= 1'b0;
    end
    else if(cpu_cen) begin
        mcu_wr   <= 1'b0;
        mcu_rd   <= 0;
        if( bank_cs ) bank <= cpu_dout[3:0];
        if( mcu_cs ) begin
            mcu_din  <= cpu_dout;
            mcu_wr   <= !wr_n;
            mcu_rd   <= wr_n;
        end
        if( video_cs ) begin
            // bits 0,1 coin counters
            CHRON    <= ~cpu_dout[7];
            flip     <=  cpu_dout[6];
            sres_b   <= ~cpu_dout[5]; // inverted through NPN
        end
        if( en_cs ) begin
            SCRON    <= ~cpu_dout[1];
            OBJON    <= ~cpu_dout[2];
        end
        if( scr_bank_cs  ) scr_bank   <= cpu_dout[1:0];
        if( snd_latch_cs ) snd_latch  <= cpu_dout;
        if( layout_cs    ) scr_layout <= cpu_dout[0];
    end

jt12_rst u_rst(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .rst_n  ( t80_rst_n )
);

reg [7:0] cabinet_input;

always @(*)
    case( A[2:0] )
        3'd0: cabinet_input = { coin, // COINS IN0
                     service, // undocumented. D5 & D4 what are those?
                     1'b1,    // tilt?
                     1'b1,
                     1'b1,
                     cab_1p }; // START
        3'd1: cabinet_input = { 2'b11, joystick1 }; // IN1
        3'd2: cabinet_input = { 2'b11, joystick2 }; // IN2
        3'd3: cabinet_input = dipsw_b;
        3'd4: cabinet_input = dipsw_a;
        3'd5: cabinet_input = 8'hff; //dip_pause, LVBL?;
        default: cabinet_input = 8'hff;
    endcase


// RAM, 16kB
wire cpu_ram_we = ram_cs && !wr_n;
assign cpu_AB = A[12:0];

wire [12:0] RAM_addr = blcnten ? {4'b1111, obj_AB} : cpu_AB;
wire RAM_we   = blcnten ? 1'b0 : cpu_ram_we;

jtframe_ram #(.AW(13),.CEN_RD(0)) RAM(
    .clk        ( clk       ),
    .cen        ( cpu_cen   ),
    .addr       ( RAM_addr  ),
    .data       ( cpu_dout  ),
    .we         ( RAM_we    ),
    .q          ( ram_dout  )
);


always @(*) begin
    cpu_din = 8'hff;
    case( 1'b1 )
        // ram_cs : cpu_din = A==16'hf3a1 && ram_dout==8'd0 ? 8'd4 : ram_dout; // cheat to start on level 5
        ram_cs : cpu_din = ram_dout;
        char_cs: cpu_din = char_dout;
        scr_cs : cpu_din = scr_dout;
        rom_cs : cpu_din = rom_data;
        in_cs  : cpu_din = cabinet_input;
        mcu_cs : cpu_din = mcu_dout;
        default:;
    endcase
end

always @(A,bank) begin
    rom_addr[13:0]  = A[13:0];
    rom_addr[18:14] = A[15] ? { 1'b0, bank } : {3'h4, A[15:14] };
end

/////////////////////////////////////////////////////////////////
// wait_n generation
wire cpu_cenw;

jtframe_z80wait #(2) u_wait(
    .rst_n      ( t80_rst_n ),
    .clk        ( clk       ),
    .cen_in     ( cpu_cen   ),
    .cen_out    ( cpu_cenw  ),
    // manage access to shared memory
    .dev_busy   ( { scr_busy, char_busy } ),
    // manage access to ROM data from SDRAM
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    // unused
    .busak_n    ( busak_n   ),
    .iorq_n     ( iorq_n    ),
    .mreq_n     ( mreq_n    ),
    .gate       (           )
);


///////////////////////////////////////////////////////////////////
// interrupt generation.
reg int_n, int_rqb, int_rqb_last;
wire int_rqb_negedge = !int_rqb && int_rqb_last;

always @(posedge clk, posedge rst)
    if(rst) begin
        int_n <= 1'b1;
    end else if(cpu_cen) begin
        int_rqb_last <= int_rqb;
        int_rqb <= LVBL;
        if( irq_ack )
            int_n <= 1'b1;
        else
            if ( int_rqb_negedge && dip_pause ) int_n <= 1'b0;
    end

jtframe_z80 u_cpu(
    .rst_n      ( t80_rst_n   ),
    .clk        ( clk         ),
    .cen        ( cpu_cenw    ),
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

//`ifdef SIMULATION
//reg [15:0] Acode;
//always @(posedge rom_ok)
//    Acode <= A;
//    //if( rom_cs ) $display("%1X,%4X (%5X) -> %2X", bank, A, rom_addr, rom_data );
//`endif

endmodule // jtgng_main