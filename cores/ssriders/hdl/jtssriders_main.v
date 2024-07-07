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
    Date: 7-7-2024 */

module jtssriders_main(
    input                rst,
    input                clk, // 48 MHz
    input                LVBL,

    output        [19:1] main_addr,
    output        [ 1:0] ram_dsn,
    output        [15:0] cpu_dout,
    // 8-bit interface
    output               cpu_we,
    output reg           pal_cs,
    output reg           pcu_cs,
    // Sound interface
    output               snd_wrn,   // K053260 (PCM sound)
    input         [ 7:0] snd2main,  // K053260 (PCM sound)
    output reg           sndon,     // irq trigger

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
    input                tile_irqn,
    input                prot_irqn,

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
    output        [ 7:0] st_dout,
    input         [ 7:0] debug_bus
);
`ifndef NOMAIN
wire [23:1] A;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, allFC, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
reg         cab_cs, snd_cs, punk_cab,
            dip_cs, dip3_cs, syswr_cs, iowr_cs, int16en;
reg  [15:0] cpu_din, cab_dout;
wire        bus_cs, bus_busy, BUSn;
wire        dtac_mux;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign main_addr= A[18:1];
assign ram_dsn  = {UDSn, LDSn};
assign IPLn     = { tile_irqn, 1'b1, prot_irqn };
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | ( ram_cs & ~ram_ok);
assign BUSn     = ASn | (LDSn & UDSn);

assign cpu_we   = ~RnW;

assign st_dout  = { rmrd, 1'd0, prio, div8, game_id };
assign VPAn     = ~( A[23] & ~ASn );
assign dtac_mux = DTACKn | ~vdtac;
assign snd_wrn  = ~(snd_cs & ~RnW);

always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    pal_cs   = 0;
    iowr_cs  = 0;
    cab_cs   = 0;
    syswr_cs = 0;
    vram_cs  = 0;
    obj_cs   = 0;
    snd_cs   = 0;
    sndon    = 0;
    pcu_cs   = 0;
    if(!ASn) case(A[23:20])
        0: rom_cs = 1;
        1: case(A[19:18])
            0: ram_cs  = 1;
            1: pal_cs  = 1; // 14'xxxx
            2: obj_cs  = 1; // 18'xxxx (not all A bits go to OBJ chip 053245)
            3:
        endcase
        5: case(A[19:16])
            4'ha:
            4'hc: case(A[11:8])
                6: begin
                    snd_cs = !A[2]; // 053260
                    sndon  =  A[2];
                end
                7: prio_cs = 1;     // 053251
        endcase
        6: vram_cs = 1;
    endcase
end

always @(posedge clk) begin
    cpu_din <= rom_cs  ? rom_data  :
               ram_cs  ? ram_dout  :
               obj_cs  ? {2{oram_dout}} :
               vram_cs ? {2{vram_dout}} :
               pal_cs  ? pal_dout       :
               snd_cs  ? {8'd0,snd2main}:
               cab_cs  ? cab_dout :
               { 16'hffff };
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

// always @(posedge clk, posedge rst) begin
//     if( rst ) begin
//         prio    <= 0;
//         rmrd    <= 0;
//         int16en <= 0;
//     end else begin
//         if( syswr_cs ) prio <= cpu_dout[3:2];
//         if( iowr_cs  ) begin
//             case(game_id)
//                 PUNKSHOT:
//                     { rmrd, sndon } <= cpu_dout[3:2];
//                 default:
//                     { rmrd, int16en, sndon } <= {cpu_dout[7], cpu_dout[5], cpu_dout[3]};
//             endcase
//         end
//     end
// end

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
    .den        ( 6'd3      ),  // denominator, 3 (16MHz)
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    // Frequency report
    .fave       (           ),
    .fworst     (           )
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
    initial begin
        sndon   = 0;
        obj_cs  = 0;
        pal_cs  = 0;
        pcu_cs  = 0;
        prio    = 0;
        ram_cs  = 0;
        rmrd    = 0;
        rom_cs  = 0;
        vram_cs = 0;
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
