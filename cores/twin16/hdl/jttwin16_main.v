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
    Date: 27-8-2023 */

module jttwin16_main(
    input                rst,
    input                clk, // 48 MHz
    input                LVBL,
    input         [ 2:0] game_id,

    output        [18:1] main_addr,
    output        [ 1:0] ram_dsn,
    output        [15:0] cpu_dout,
    // 8-bit interface
    output               cpu_we,
    output reg           pal_cs,

    output reg           rom_cs,
    output reg           ram_cs,
    output reg           vram_cs,
    output reg           oram_cs,

    // video RAM outputs,
    input         [ 7:0] ma_dout,   // scroll A
    input         [ 7:0] mb_dout,   // scroll B
    input         [ 7:0] mf_dout,   // fixed layer
    input         [ 7:0] mo_dout,   // objects
    input         [15:0] pal_dout,
    output        [ 1:0] va_we,
    output        [ 1:0] vb_we,
    output        [ 1:0] fx_we,
    output        [ 1:0] obj_we,

    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,

    // Sound interface
    output reg    [ 7:0] snd_latch,
    output reg           sndon,

    // video configuration
    output reg    [ 1:0] prio,
    output reg    [ 2:0] hscr1, hscr2,
    output reg    [ 9:0] obj_offsetx, obj_offsety,

    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input         [ 1:0] start_button,
    input         [ 1:0] coin_input,
    input                service,
    input                dip_pause,
    input                dip_test,
    input         [19:0] dipsw,
    output        [ 7:0] st_dout,
    input         [ 7:0] debug_bus
);
`ifndef NOMAIN

`include "game_id.inc"

wire [23:1] A;
wire [ 1:0] dws;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, allFC, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
reg         snd_cs, dip_cs, syswr_cs, vbank_cs,
            crom_cs, oram_cs, int16en;
reg  [15:0] cpu_din;
reg  [ 7:0] cab_dout;
reg         intn, LVBLl;
wire        bus_cs, bus_busy, BUSn;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign main_addr= A[18:1];
assign ram_dsn  = {UDSn, LDSn};
assign IPLn     = { intn, 1'b1, intn };
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | ( ram_cs & ~ram_ok);
assign BUSn     = ASn | (LDSn & UDSn);

assign cpu_we   = ~RnW;

assign st_dout  = { 6'd0, prio };
assign VPAn     = ~( A[23] & ~ASn );
assign dws      = ~({2{RnW}} & {UDSn, LDSn});
assign va_we    = dws & {2{vram_cs & ~A[13]}};
assign vb_we    = dws & {2{vram_cs &  A[13]}};
assign fx_we    = dws & {2{fix_cs}};
assign obj_we   = dws & {2{oram_cs}};

always @* begin
    fix_cs   = 0;
    vram_cs  = 0;
    oram_cs   = 0;
    rom_cs   = 0;
    ram_cs   = 0;
    pal_cs   = 0;
    io_cs    = 0;
    syswr_cs = 0;
    vbank_cs = 0;
    crom_cs  = 0;
    orom_cs  = 0;
    if(!ASn && !A[23]) begin
        case( A[22:21] )
            0: casez( A[20:17] )
                4'b1?00: fix_cs   = 1;
                4'b1?01: vram_cs  = 1;
                4'b1?10: oram_cs   = 1;
                4'b000?: rom_cs   = 1;
                4'b0010: ram_cs   = !BUSn;
                4'b0100: pal_cs   = 1;
                4'b0101: io_cs    = 1;
                4'b0110: syswr_cs = !RnW;
                4'b0111: vbank_cs = 1;
                default:;
            endcase
            2: crom_cs = 1;
            3: orom_cs = 1;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    cpu_din <= rom_cs  ? rom_data  :
               ram_cs  ? ram_dout  :
               oram_cs ? mo_dout   :
               vram_cs ? (A[13] ? mb_dout : ma_dout ) :
               fix_cs  ? mf_dout  :
               pal_cs  ? pal_dout :
               io_cs   ? { 8'd0, cab_dout } :
               16'hffff;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        LVBLl <= 0;
        intn  <= 0;
    end else begin
        LVBLl <= LVBL;
        if( !LVBL && LVBLl )
            intn <= 0;
        if( !int16en )
            intn <= 1;
    end
end

always @(posedge clk) begin
    case( A[4:3] )
        0: case( A[2:1] )
            0: cab_dout <= {1'b1, service, 1'b1, start_button[1:0], 1'b1, coin_input[1:0] };
            1: cab_dout <= { 1'b1, joystick1 };
            2: cab_dout <= { 1'b1, joystick2 };
            default: cab_dout <= 0;
        endcase
        2: cab_dout <= A[1] ? dipsw[15:8] : dipsw[7:0];
        3: cab_dout <= { 4'h0, dipsw[3:0] };
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        prio        <= 0;
        hscr1       <= 0;
        hscr2       <= 0;
        obj_offsetx <= 0;
        obj_offsety <= 0;
        int16en     <= 0;
        sndon       <= 0;
    end else begin
        if( syswr_cs )
            case( A[3:1] )
                0:  { prio, hflip, vflip } <= cpu_dout[3:0];
                1: obj_offsetx <= cpu_dout[9:0];
                2: obj_offsety <= cpu_dout[9:0];
                3: hscr1       <= cpu_dout[2:0];
                5: hscr2       <= cpu_dout[2:0];
                default:;
            endcase
        if( io_cs && !A[16] ) begin
            case( {RnW, A[4:3]} )
                0: { crtkill, dma_on, int16en, sndon } <= cpu_dout[7:3];
                1: snd_latch <= cpu_dout[7:0];
                default:;
            endcase
        end
    end
end

jtframe_68kdtack #(.W(6),.RECOVERY(1)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 5'd24     ),  // numerator
    .den        ( 6'd125    ),  // denominator, 48*24/125 = 9216
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    // Frequency report
    .fave       (           ),
    .fworst     (           ),
    .frst       (           )
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
    .HALTn      ( dip_pause   ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        ) // VBLANK
);
`else
    integer framecnt=0;
    always @(posedge LVBL) begin
        framecnt <=framecnt+1;
        sndon    <=framecnt==10;
    end
    initial begin
        // sndon  = 0;
        oram_cs    = 0;
        pal_cs    = 0;
        pcu_cs    = 0;
        prio      = 0;
        ram_cs    = 0;
        rmrd      = 0;
        rom_cs    = 0;
        snd_latch = 'h63;
        vram_cs   = 0;
    end
    assign
        cpu_dout  = 0,
        cpu_we    = 0,
        main_addr = 0,
        ram_dsn   = 0,
        snd_wrn   = 0,
        st_dout   = 0;
`endif
endmodule
