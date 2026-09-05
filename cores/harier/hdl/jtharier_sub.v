/* SPDX-FileCopyrightText: 2026 Chris Watson/Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-8-2026 */

module jtharier_sub(
    input              rst,
    input              clk,

    // Held by the main CPU through the sub 8255 port A
    input              rstn,
    input              intn,

    // Shared RAM and road RAM, dual ported through the LS157 mux IC80-IC83,
    // CPU sheet 3/6
    output reg         ram_cs,
    input       [15:0] ram_dout,
    output reg         road_cs,
    input       [15:0] road_dout,

    output      [15:1] addr,
    output      [15:0] cpu_dout,
    output             RnW,
    output      [ 1:0] dsn,

    // Program ROM EPR-7182/7183, CPU sheet 3/6
    output reg         rom_cs,
    input       [15:0] rom_data,
    input              rom_ok,

    input       [ 7:0] st_addr,
    output reg  [ 7:0] st_dout
);
`ifndef NOSUB
wire [23:1] A;
wire [ 2:0] FC, IPLn;
wire        ASn, UDSn, LDSn, VPAn, DTACKn;
wire [15:0] cpu_dout_raw;
wire        cpu_cen, cpu_cenb;
reg  [15:0] cpu_din;
wire        rom_ok_dly;
wire [15:0] fave, fworst;

wire        inta_n = ~&{ FC, ~ASn };

assign addr     = A[15:1];
assign cpu_dout = cpu_dout_raw;
// RAW strobes, deliberately: every consumer of sub_dsn qualifies itself with
// ~sub_rnw, and nothing on this bus derives a write enable from the strobes
// alone. main.v exports RnW-qualified strobes because jts16_char does.
assign dsn      = { UDSn, LDSn };
assign IPLn     = { intn, 2'b11 };  // level 4, sub_control_adc_w bit 6
assign VPAn     = inta_n;

wire        bus_cs   = rom_cs | ram_cs | road_cs;
wire        bus_busy = rom_cs & ~rom_ok_dly;

jtframe_okdly u_okdly(
    .rst    ( rst        ),
    .clk    ( clk        ),
    .cs     ( rom_cs     ),
    .ok     ( rom_ok     ),
    .ok_dly ( rom_ok_dly )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_cs  <= 0;
        ram_cs  <= 0;
        road_cs <= 0;
    end else begin
        if( !ASn && FC!=3'b111 && {UDSn,LDSn}!=2'b11 ) begin
            rom_cs  <= !A[18];
            road_cs <=  A[18:16]==3'd6;
            ram_cs  <=  A[18:16]==3'd7;
        end else begin
            rom_cs  <= 0;
            ram_cs  <= 0;
            road_cs <= 0;
        end
    end
end

always @(posedge clk) begin
    cpu_din <= rom_cs  ? rom_data  :
               ram_cs  ? ram_dout  :
               road_cs ? road_dout : 16'hffff;
end

always @(posedge clk) begin
    case( st_addr[2:0] )
        3'd0: st_dout <= { 5'd0, road_cs, ram_cs, rom_cs };
        3'd1: st_dout <= { 6'd0, intn, rstn };
        3'd2: st_dout <= A[8:1];
        3'd3: st_dout <= A[16:9];
        3'd4: st_dout <= fave[ 7:0];
        3'd5: st_dout <= fave[15:8];
        3'd6: st_dout <= fworst[ 7:0];
        3'd7: st_dout <= fworst[15:8];
        default: st_dout <= 0;
    endcase
end

jtharier_dtack_cen u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .UDSn       ( UDSn      ),
    .LDSn       ( LDSn      ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .DTACKn     ( DTACKn    ),
    .fave       ( fave      ),
    .fworst     ( fworst    )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst | ~rstn ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout_raw),

    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),

    .BERRn      ( 1'b1        ),
    .HALTn      ( 1'b1        ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        )
);

`else

initial begin
    rom_cs  = 0;
    ram_cs  = 0;
    road_cs = 0;
    st_dout = 0;
end

assign addr     = 0;
assign cpu_dout = 0;
assign RnW      = 1;
assign dsn      = 3;

`endif

endmodule
