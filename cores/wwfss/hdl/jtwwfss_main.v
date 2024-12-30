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
    Date: 27-8-2024 */

module jtwwfss_main(
    input                rst,
    input                clk, // 48 MHz
    input                v8,
    input                LVBL,

    output        [17:1] main_addr,
    output        [ 1:0] main_dsn,
    output        [15:0] main_dout,

    output        [ 1:0] cram_we,
    output        [ 1:0] scr_we,
    output               oram_we,
    output        [ 1:0] pal_we,

    input         [ 7:0] fix_dout,
    input         [ 7:0] scr_dout,
    input         [ 7:0] oram_dout,
    input         [15:0] pal_dout,
    output reg    [ 8:0] scrx, scry,

    output               ram_we,
    output reg           ram_cs,
    input                ram_ok,
    input         [15:0] ram_dout,

    output reg           rom_cs,
    input                rom_ok,
    input         [15:0] rom_data,

    // Sound interface
    output reg           snd_on,
    output reg    [ 7:0] snd_latch,

    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input         [ 1:0] cab_1p,
    input         [ 1:0] coin,
    input                service,
    input                dip_pause,
    input         [ 7:0] dipsw_a,
    input         [ 7:0] dipsw_b
);
`ifndef NOMAIN
wire [23:1] A;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn, BUSn;
wire [ 2:0] FC, IPLn;
reg         iord_cs, fix_cs, pal_cs, int6_clr, int5_clr,
            scr_cs, oram_cs, scrx_cs, scry_cs;
reg  [ 7:0] cab_dout;
reg  [15:0] cpu_din;
wire [15:0] cpu_dout;
reg         intn, LVBLl;
wire        bus_cs, bus_busy, bus_legit, int5, int6, c_button;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign main_addr = A[17:1];
assign main_dsn  = {UDSn, LDSn};
assign main_dout = cpu_dout;
assign IPLn      = ~(int6 ? 3'd6 : int5 ? 3'd5 : 3'd0);
assign VPAn      = !(!ASn && FC==7);
assign bus_cs    = rom_cs | ram_cs;
assign bus_busy  = (rom_cs & ~rom_ok) | (ram_cs & ~ram_ok);
assign bus_legit = 0; // fix_cs & ~sdakn;
assign BUSn      = LDSn & UDSn;

assign cram_we   = {~A[1],A[1]} & {2{fix_cs  & ~RnW & ~LDSn}};
assign scr_we    = {~A[1],A[1]} & {2{scr_cs  & ~RnW & ~LDSn}};
assign oram_we   = oram_cs & ~RnW & ~LDSn;
assign pal_we    = {2{pal_cs & ~RnW}} & ~main_dsn;
assign ram_we    = ram_cs & ~RnW;
assign c_button  = joystick1[6] & joystick2[6]; // used for 1p/2p vs CPU

always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    fix_cs   = 0;
    scr_cs   = 0;
    oram_cs  = 0;
    pal_cs   = 0;
    iord_cs  = 0;
    int6_clr = 0;
    int5_clr = 0;
    snd_on   = 0;
    scrx_cs  = 0;
    scry_cs  = 0;
    if(!ASn) case(A[20:18])
        0: rom_cs  = 1;
        2: fix_cs  = 1;
        3: scr_cs  = 1;
        4: oram_cs = 1;
        5: pal_cs  = 1;
        6: begin
            iord_cs = RnW;
            if(!LDSn && !RnW) case(A[3:1])
                0: int6_clr = 1;
                1: int5_clr = 1;
                2: scrx_cs  = 1;
                3: scry_cs  = 1;
                4: snd_on   = 1;
                // 5: coin lock // 6-bit flip flop. MAME assigns flip to bit 0 but it is dangling on the PCB
                default:;
            endcase
        end
        7: ram_cs = ~BUSn;
        default:;
    endcase
end

always @(posedge clk) begin
    if( snd_on  ) snd_latch <= cpu_dout[7:0];
    if( scrx_cs ) scrx      <= cpu_dout[8:0];
    if( scry_cs ) scry      <= cpu_dout[8:0];

    cpu_din <= rom_cs  ? rom_data  :
               ram_cs  ? ram_dout  :
               pal_cs  ? pal_dout  :
               fix_cs  ? { 8'h0, fix_dout  } :
               oram_cs ? { 8'h0, oram_dout } :
               scr_cs  ? { 8'h0, scr_dout  } :
               iord_cs ? { 8'h0, cab_dout  } : 16'h0;
end

always @(posedge clk) begin
    case( A[3:1] )
        0: cab_dout <= dipsw_a;
        1: cab_dout <= dipsw_a;
        2: cab_dout <= { cab_1p[0], joystick1[6:0] };
        3: cab_dout <= { cab_1p[1], c_button, joystick2[5:0] };
        4: cab_dout <= { 4'd0, service, coin, ~LVBL }; // should it be ~LVBL?
        default:;
    endcase
end

jtframe_edge #(.QSET(1)) u_int5(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( v8        ), // should it be ~v8?
    .clr    ( int5_clr  ),
    .q      ( int5      )
);


jtframe_edge #(.QSET(1)) u_int6(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( ~LVBL     ),
    .clr    ( int6_clr  ),
    .q      ( int6      )
);

jtframe_68kdtack_cen #(.W(8)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( bus_legit ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 7'd5      ),  // numerator
    .den        ( 8'd24     ),  // denominator
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

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        ) // VBLANK
);
`else
    integer f, fcnt;
    reg [7:0] mem[0:3];
    assign
        main_addr = 0,
        main_dsn  = 0,
        main_dout = 0,
        cram_we   = 0,
        scr_we    = 0,
        oram_we   = 0,
        pal_we    = 0,
        ram_we    = 0;
    initial begin
        f = $fopen("rest.bin","rb");
        if(f==0) begin
            scrx = 0;
            scry = 0;
        end else begin
            fcnt = $fread(mem,f);
            $display("Read %01d bytes for scroll data",fcnt);
            scrx = {mem[1][0],mem[0]};
            scry = {mem[3][0],mem[2]};
            $display("scroll x = %X\nscroll y = %X",scrx, scry);
            $fclose(f);
        end
        ram_cs    = 0;
        rom_cs    = 0;
        snd_on    = 0;
        snd_latch = 0;
    end
`endif
endmodule
