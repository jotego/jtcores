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
    Date: 12-8-2023 */

module jttmnt_main(
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
    output reg           pcu_cs,
    // K053260 (PCM sound in Punk Shot)
    output               snd_wrn,
    input         [ 7:0] snd2main,

    output reg           rom_cs,
    output reg           ram_cs,
    output reg           vram_cs,
    output reg           obj_cs,

    input         [ 7:0] oram_dout,
    input         [ 7:0] vram_dout,
    input         [15:0] pal_dout,
    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,
    input                vdtac,
    input                odtac,
    input                tile_irqn,
    input                tile_nmin,

    // Sound interface
    output reg    [ 7:0] snd_latch,
    output reg           sndon,

    // video configuration
    output reg           rmrd,
    output reg    [ 1:0] prio,

    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input         [ 6:0] joystick3,
    input         [ 6:0] joystick4,
    input         [ 3:0] cab_1p,
    input         [ 3:0] coin,
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
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, allFC, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
reg         snddt_cs, shoot_cs, snd_cs, punk_cab,
            dip_cs, dip3_cs, syswr_cs, iowr_cs, int16en;
reg  [15:0] cpu_din, cab_dout;
reg         intn, LVBLl, div8;
wire        bus_cs, bus_busy, BUSn;
wire        dtac_mux;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign main_addr= A[18:1];
assign ram_dsn  = {UDSn, LDSn};
assign IPLn     = game_id==PUNKSHOT ? { tile_irqn & tile_nmin, 1'b1, tile_nmin } : { intn, 1'b1, intn };
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | ( ram_cs & ~ram_ok);
assign BUSn     = ASn | (LDSn & UDSn);

assign cpu_we   = ~RnW;

assign st_dout  = { rmrd, 1'd0, prio, div8, game_id };
assign VPAn     = ~( A[23] & ~ASn );
assign dtac_mux = (vram_cs | obj_cs) ? (vdtac & odtac) : DTACKn;
assign snd_wrn  = ~(snd_cs & ~RnW);

always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    pal_cs   = 0;
    iowr_cs  = 0;
    snddt_cs = 0;
    shoot_cs = 0;
    dip_cs   = 0;
    dip3_cs  = 0;
    syswr_cs = 0;
    vram_cs  = 0;
    obj_cs   = 0;
    snd_cs   = 0;
    pcu_cs   = 0;
    punk_cab = 0;
    if(!ASn) begin
        if(!A[20]) case( A[19:17] )
            0,1: rom_cs = 1;  // 0'0000 ~ 3'FFFF
            2: case( game_id )  // 4'0000 ~ 5'FFFF
                TMNT: rom_cs = 1;
                MIA:  ram_cs = ~BUSn;
                default:;
            endcase
            3: case( game_id )  // 6'0000 ~ 7'FFFF
                TMNT, MIA: ram_cs = ~BUSn;
                default:;
            endcase
            4: case( game_id )  // 8'0000 ~ 9'FFFF
                PUNKSHOT: begin
                    ram_cs = !A[16] && ~BUSn;
                    pal_cs =  A[16] && A[15:12]==0;
                end
                default:  pal_cs = 1;
            endcase
            5: case( game_id )
                    PUNKSHOT: //  A'0000 ~ A'FFFF
                    case( A[7:5] )
                        0: punk_cab  = 1; // A'000x
                        1: iowr_cs   = 1; // A'002x
                        2: snd_cs    = 1; // A'004x
                        3: pcu_cs    = 1; // A'006x
                        // 4: watchdog
                        default:;
                    endcase
                    default:
                    if(!A[16]) case( { RnW, A[4:3] } )
                        0: iowr_cs  = 1;
                        1: snddt_cs = 1;
                        // 2: watchdog
                        4: shoot_cs = 1;
                        6: dip_cs   = 1;
                        7: dip3_cs  = 1;
                        default:;
                    endcase
                endcase
            6: case( game_id )  // C'0000 ~ C'FFFF
                TMNT, MIA: syswr_cs = 1;
                default:;
            endcase
            default:;
        endcase else
            case( game_id )
                PUNKSHOT:
                    case(A[18:16]) // 10'0000 ~
                        0: vram_cs = 1;
                        1: obj_cs  = 1;
                        default:;
                    endcase
                default:
                    case(A[18:17]) // 10'0000 ~
                        0: vram_cs = 1;
                        2: obj_cs  = 1;
                        default:;
                    endcase
            endcase
    end
end

always @(posedge clk) begin
    cpu_din <= rom_cs  ? rom_data  :
               ram_cs  ? ram_dout  :
               obj_cs  ? {2{oram_dout}} :
               vram_cs ? {2{vram_dout}} :
               pal_cs  ? pal_dout       :
               snd_cs  ? {8'd0,snd2main}:
               dip3_cs ? { 12'd0, dipsw[19:16] } :
               (shoot_cs | dip_cs | punk_cab) ? cab_dout :
               { 16'hffff };
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

always @(posedge rmrd) $display("RMRD high");

always @(posedge clk) begin
    cab_dout[15:8] <= 0;
    if(dip_cs) case( A[2:1] )
        ~2'd0: cab_dout[7:0] <= 0;
        ~2'd1: cab_dout[7:0] <= game_id == TMNT ? { cab_1p[3], joystick4[6:0] } : 8'hff;
        ~2'd2: cab_dout[7:0] <= dipsw[15:8];
        ~2'd3: cab_dout[7:0] <= dipsw[7:0];
    endcase
    else case( A[2:1] )
        ~2'd0: cab_dout[7:0] <= game_id == TMNT ? { cab_1p[2], joystick3[6:0] } : 8'hff;
        ~2'd1: cab_dout[7:0] <= { cab_1p[1], joystick2[6:0] };
        ~2'd2: cab_dout[7:0] <= { cab_1p[0], joystick1[6:0] };
        ~2'd3: cab_dout[7:0] <= game_id == TMNT ? { {4{service}}, coin } :
                            { 1'b1, service, 1'b1, cab_1p[1:0], 1'b1, coin[1:0] };
    endcase
    if( punk_cab ) begin // 16-bit interface
        case( A[2:1] )
            ~2'd0: cab_dout <= { 1'b1, joystick2[6:0],  1'b1, joystick1[6:0] };
            ~2'd1: cab_dout <= { 1'b1, joystick4[6:0],  1'b1, joystick3[6:0] };
            ~2'd2: cab_dout <= { dipsw[19:16], 1'b1, dip_test, cab_1p[1:0], {4{service}}, coin };
            ~2'd3: cab_dout <= dipsw[15:0];
        endcase
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        prio    <= 0;
        rmrd    <= 0;
        int16en <= 0;
        sndon   <= 0;
        div8    <= 0;
    end else begin
        div8 <= game_id != PUNKSHOT;
        if( syswr_cs ) prio <= cpu_dout[3:2];
        if( iowr_cs  ) begin
            case(game_id)
                PUNKSHOT:
                    { rmrd, sndon } <= cpu_dout[3:2];
                default:
                    { rmrd, int16en, sndon } <= {cpu_dout[7], cpu_dout[5], cpu_dout[3]};
            endcase
        end
        if( snddt_cs ) snd_latch <= cpu_dout[7:0];
    end
end

jtframe_68kdtack_cen #(.W(6),.RECOVERY(1)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 5'd1      ),  // numerator
    .den        ({4'b1,div8,1'd0}),  // denominator, 4 (12MHz) or 6 (8MHz)
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

    .DTACKn     ( dtac_mux    ),
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
        obj_cs    = 0;
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
