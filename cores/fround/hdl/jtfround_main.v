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

module jtfround_main(
    input                rst,
    input                clk, // 48 MHz
    input                LVBL,
    // input         [ 2:0] game_id,

    output        [19:1] main_addr,
    output        [ 1:0] ram_dsn,
    output        [15:0] cpu_dout,
    // 8-bit interface
    output               cpu_we,
    output               pal_we,

    // video status
    output reg           rom_cs,
    output reg           ram_cs,
    output reg           crtkill,
    output reg           dma_on,
    input                dma_bsy,
    input                tim,

    // video ROM checks
    input         [31:0] scr_data,
    input                scr_ok,
    input         [31:0] obj_data,
    input                obj_ok,

    // video RAM outputs,
    input         [15:0] ma_dout,   // scroll A
    input         [15:0] mb_dout,   // scroll B
    input         [15:0] mf_dout,   // fixed layer
    input         [15:0] mo_dout,   // objects
    input         [ 7:0] mp_dout,
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
    output reg           hflip, vflip,
    output reg    [ 1:0] prio,
    output reg    [ 8:0] scra_x, scra_y, scrb_x, scrb_y,
    output reg    [ 9:0] obj_dx, obj_dy,
    output reg    [15:0] scr_bank,

    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input         [ 1:0] cab_1p,
    input         [ 1:0] coin,
    input                service,
    input                dip_pause,
    input                dip_test,
    input         [19:0] dipsw,
    output reg    [ 7:0] st_dout,
    input         [ 7:0] debug_bus
);
`ifndef NOMAIN

wire [23:1] A;
wire [ 1:0] dws;
wire        cpu_cen, cpu_cenb, pre_dtackn;
wire        UDSn, LDSn, RnW, allFC, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
reg         fix_cs, snd_cs, syswr_cs, vbank_cs, io_cs, vram_cs, oram_cs,
            pal_cs, dma_cs, crom_cs, orom_cs, int16en;
reg  [15:0] cpu_din;
reg  [ 7:0] cab_dout;
reg         intn, LVBLl;
wire        bus_cs, bus_busy, BUSn;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign main_addr= A[19:1];
assign ram_dsn  = {UDSn, LDSn};
assign IPLn     = { intn, 1'b1, intn };
assign bus_cs   = rom_cs | ram_cs | crom_cs | orom_cs;
assign bus_busy = (rom_cs  & ~rom_ok) | (ram_cs  & ~ram_ok) |
                  (crom_cs & ~scr_ok) | (orom_cs & ~obj_ok);
assign BUSn     = ASn | (LDSn & UDSn);

assign cpu_we   = ~RnW;
assign pal_we   = pal_cs & cpu_we & ~LDSn;
assign VPAn     = ~( A[23] & ~ASn );
assign dws      = ~({2{RnW}} | {UDSn, LDSn});
assign va_we    = dws & {2{vram_cs & ~A[13]}};
assign vb_we    = dws & {2{vram_cs &  A[13]}};
assign fx_we    = dws & {2{fix_cs}};
assign obj_we   = dws & {2{oram_cs}};
assign DTACKn   = (~(vram_cs | oram_cs ) | tim) & pre_dtackn;

always @* begin
    case( debug_bus[3:0] )
        0: st_dout = scra_x[7:0];
        1: st_dout = scrb_x[7:0];
        2: st_dout = scra_y[7:0];
        3: st_dout = scrb_y[7:0];
        4: st_dout = { vflip, hflip, prio, scrb_y[8],scra_y[8], scrb_x[8], scra_x[8] };
        5: st_dout = scr_bank[ 7:0];
        6: st_dout = scr_bank[15:8];
        7: st_dout = obj_dx[ 7:0];
        8: st_dout = { 6'd0, obj_dx[9:8] };
        9: st_dout = obj_dy[ 7:0];
       10: st_dout = { 6'd0, obj_dy[9:8] };
       11: st_dout = { dma_on, 1'd0, crtkill, int16en, 2'd0, prio };
       default: st_dout = 0;
    endcase
end

always @* begin
    fix_cs   = 0;
    vram_cs  = 0;
    oram_cs   = 0;
    rom_cs   = 0;
    ram_cs   = 0;
    pal_cs   = 0;
    io_cs    = 0;
    syswr_cs = 0;
    dma_cs   = 0;
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
                4'b0101: io_cs    = 1;     // A'0000~
                4'b0110: begin
                    dma_cs   = RnW;
                    syswr_cs = !RnW;
                end
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
               pal_cs  ? { 8'd0, mp_dout } :
               io_cs   ? { 8'd0, cab_dout } :
               dma_cs  ? { 15'd0, dma_bsy } :
               crom_cs ? ( A[1] ? scr_data[31:16] : scr_data[15:0] ) :
               orom_cs ? ( A[1] ? obj_data[31:16] : obj_data[15:0] ) :
               16'h0;
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
            0: cab_dout <= {1'b1, service, 1'b1, cab_1p[1:0], 1'b1, coin[1:0] };
            1: cab_dout <= { 1'b1, joystick1 };
            2: cab_dout <= { 1'b1, joystick2 };
            default: cab_dout <= 8'hff;
        endcase
        2: cab_dout <= A[1] ? dipsw[7:0] : dipsw[15:8];
        3: cab_dout <= { 4'h0, dipsw[19:16] };
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        prio     <= 0;
        scra_x   <= 0;
        scra_y   <= 0;
        scrb_x   <= 0;
        scrb_y   <= 0;
        scr_bank <= 0;
        hflip    <= 0;
        vflip    <= 0;
        obj_dx   <= 0;
        obj_dy   <= 0;
        int16en  <= 0;
        sndon    <= 0;
        crtkill  <= 0;
        dma_on   <= 0;
    end else begin
        if( vbank_cs ) scr_bank <= cpu_dout;
        if( syswr_cs )
            case( A[3:1] )
                0:  { prio, hflip, vflip } <= cpu_dout[3:0];
                1: obj_dx <= cpu_dout[9:0];
                2: obj_dy <= cpu_dout[9:0];
                3: scra_x <= cpu_dout[8:0];
                4: scra_y <= cpu_dout[8:0];
                5: scrb_x <= cpu_dout[8:0];
                6: scrb_y <= cpu_dout[8:0];
                default:;
            endcase
        if( io_cs && !A[16] ) begin
            case( {RnW, A[4:3]} )
                0: {crtkill, dma_on, int16en, sndon} <= {cpu_dout[7:5],cpu_dout[3]};
                1: snd_latch <= cpu_dout[7:0];
                default:;
            endcase
        end
    end
end

jtframe_68kdtack_cen #(.W(5),.RECOVERY(1)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 4'd3      ),  // numerator
    .den        ( 5'd16     ),  // denominator, => 9216
    .DTACKn     ( pre_dtackn),
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
    integer fin, fcnt;
    reg [7:0] mmr[0:10];

    initial begin
        for( fcnt=0; fcnt<11; fcnt=fcnt+1 ) mmr[fcnt]=0;
        fin=$fopen("rest.bin","rb");
        fcnt = $fread(mmr,fin);
        $display("Read %d bytes from rest.bin",fcnt);
        $fclose(fin);

        scra_x   = { mmr[4][0], mmr[0] };
        scrb_x   = { mmr[4][1], mmr[1] };
        scra_y   = { mmr[4][2], mmr[2] };
        scrb_y   = { mmr[4][3], mmr[3] };
        prio     = mmr[4][5:4];
        hflip    = mmr[4][6];
        vflip    = mmr[4][7];
        scr_bank = {mmr[6],mmr[5]};
        obj_dx   = {mmr[8][1:0],mmr[7]};
        obj_dy   = {mmr[10][1:0],mmr[9]};
    end
    // integer framecnt=0;
    // always @(posedge LVBL) begin
    //     framecnt <=framecnt+1;
    //     sndon    <=framecnt==10;
    // end
    initial begin
        rom_cs    = 0;
        ram_cs    = 0;
        crtkill   = 0;
        dma_on    = 0;

        snd_latch = 0;
        sndon     = 0;

        st_dout   = 0;
    end
    assign
        main_addr = 0,
        ram_dsn   = 0,
        cpu_dout  = 0,
        cpu_we    = 0,
        pal_we    = 0,
        va_we     = 0,
        vb_we     = 0,
        fx_we     = 0,
        obj_we    = 0;
`endif
endmodule
