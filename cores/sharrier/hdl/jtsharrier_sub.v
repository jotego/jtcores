/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-8-2026 */

module jtsharrier_sub #(
    parameter MCLK_KHZ = 50_347 // see jtsharrier_main
)(
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

// S.CLK is buffered from the same 10 MHz XTAL1 as the main CPU, sheet 1/6.
localparam        CPU_KHZ  = 10_000;
localparam [ 7:0] FDEN     = 8'd156;
localparam [31:0] FNUM     = (CPU_KHZ*FDEN + MCLK_KHZ/2)/MCLK_KHZ;

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

// jtframe_okdly gates ok by cs, so a stale ok from the previous access cannot
// assert DTACKn before the new read completes (#1516).
jtframe_okdly u_okdly(
    .rst    ( rst        ),
    .clk    ( clk        ),
    .cs     ( rom_cs     ),
    .ok     ( rom_ok     ),
    .ok_dly ( rom_ok_dly )
);

// Only 19 address lines are decoded. Two of the six drawn ROM sockets are
// populated, so the 64 kB image repeats through the 256 kB the decode allows.
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_cs  <= 0;
        ram_cs  <= 0;
        road_cs <= 0;
    end else begin
        if( !ASn && FC!=3'b111 ) begin
            rom_cs  <= !A[18];                       // 000000-03ffff
            road_cs <=  A[18:12]==7'b1101000;         // 068000-068fff
            // Shared with the main CPU at 124000-127fff. No !BUSn: it carries
            // the data strobes, which assert at S4 on a write, mistiming the
            // write half of a read-modify-write. BRAM needs no request handshake.
            ram_cs  <=  A[18:14]==5'b11111;           // 07c000-07ffff
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

jtframe_68kdtack_cen #(.W(8),.RECOVERY(1)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( FNUM[6:0] ),
    .den        ( FDEN      ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
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
