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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
            Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-8-2026 */

module jttaitox_main(
    input                rst,
    input                clk,        // 48 MHz
    input                LVBL,

    input                cchip,

    output               cpu_cen,
    output        [23:1] cpu_addr,
    output        [15:0] cpu_dout,
    output               cpu_rnw,
    output        [ 1:0] cpu_dsn,

    // 68k program ROM (SDRAM bank 0)
    output reg           rom_cs,
    output        [18:1] rom_addr,
    input         [15:0] rom_data,
    input                rom_ok,

    // Work RAM. BRAM by default; RAM_IN_SDRAM moves it to SDRAM bank 3 on the
    // devices that cannot spare the blocks. See cfg/mem.yaml and cfg/macros.def.
    output reg           ram_cs,
    input                ram_ok,
    input         [15:0] ram_data,
`ifdef RAM_IN_SDRAM
    output        [ 1:0] ram_dsn,
    output               ram_we,
`else
    output        [ 1:0] ram_we,
`endif
    output        [ 1:0] pal_we,
    input         [15:0] pal_dout,

    // X1-001 / X1-002, owned by jttaitox_video
    output reg           oram_cs,    // e00000 ORAM CS
    output reg           vdcm_cs,    // d00000 VDCM CS
    input         [15:0] vid_dout,

    // SOUND - TC0140SYT
    output               syt_rst,
    output reg           syt_cs,
    input         [ 3:0] syt_dout,

    // TC0030CMD
    output               cchip_rst,
    output reg           cchip_cs,
    input         [ 7:0] cchip_dout,


    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input         [ 1:0] start_button,
    input         [ 1:0] coin,
    input                service,
    input                tilt,
    input                dip_pause,
    input         [ 7:0] dipsw_a,
    input         [ 7:0] dipsw_b
);
`ifndef NOMAIN
wire [23:1] A;
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn,
            cpu_cenb, intn, bus_cs, bus_busy, LWRn;
wire [ 2:0] FC, IPLn;
reg  [15:0] cpu_din;
reg  [ 7:0] cab_dout;
reg         pal_cs, dip_cs, in_cs, out_cs;

assign cpu_addr = A;
assign rom_addr = A[18:1];
assign cpu_dsn  = { UDSn, LDSn };
assign cpu_rnw  = RnW;
assign LWRn     = RnW | LDSn;

always @* begin
    syt_cs   = 0;
    cchip_cs = 0;
    in_cs    = 0;
    pal_cs   = 0;
    vdcm_cs  = 0;
    oram_cs  = 0;
    ram_cs   = 0;
    rom_cs   = 0;
    dip_cs   = 0;
    out_cs   = 0;
    if( !ASn && {UDSn,LDSn}!=2'b11 && ~&FC ) begin
        // F138 #17 - A23 high
        syt_cs   =  A[23] && A[22:20]==0;
        cchip_cs =  A[23] && A[22:20]==1 &&  cchip;
        in_cs    =  A[23] && A[22:20]==1 && !cchip;  // no C-chip: direct input port
        pal_cs   =  A[23] && A[22:20]==3;
        vdcm_cs  =  A[23] && A[22:20]==5;
        oram_cs  =  A[23] && A[22:20]==6;
        ram_cs   =  A[23] && A[22:20]==7;
        // F138 #18 - A23 low
        rom_cs   = !A[23] && A[22:19]==0;
        dip_cs   = !A[23] && A[22:20]==5;
        out_cs   = !A[23] && A[22:20]==7;
    end
end

`ifdef RAM_IN_SDRAM
assign ram_we   = ram_cs & ~RnW;
assign ram_dsn  = {UDSn,LDSn};
`else
assign ram_we   = {2{ram_cs & ~RnW}} & ~{UDSn,LDSn};
`endif
assign pal_we   = {2{pal_cs & ~RnW}} & ~{UDSn,LDSn};

// The C-chip games take the VBL interrupt on level 6, the rest on level 2
// The schematics actually shown a connection from the C-chip to pin IPL2
assign IPLn     = intn ? 3'b111 : (cchip ? 3'b001 : 3'b101);
assign VPAn     = !(!ASn && FC==7);

`ifdef RAM_IN_SDRAM
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | (ram_cs & ~ram_ok);
`else
assign bus_cs   = rom_cs;
assign bus_busy = rom_cs & ~rom_ok;
`endif

always @(posedge clk) begin
    cpu_din <= rom_cs   ? rom_data  :
               ram_cs   ? ram_data  :
               pal_cs   ? pal_dout  :
               (oram_cs | vdcm_cs) ? vid_dout :
               cchip_cs ? { 8'hff, cchip_dout } :
               dip_cs   ? { 12'hfff, A[2] ? (A[1] ? dipsw_b[7:4] : dipsw_b[3:0])
                                          : (A[1] ? dipsw_a[7:4] : dipsw_a[3:0]) } :
               in_cs    ? { 8'hff, cab_dout } :
               syt_cs   ? { 12'hfff, syt_dout } :
               16'hffff;
end

always @(posedge clk) begin
    case( A[2:1] )
        0: cab_dout <= { start_button[0], joystick1[6:0] };
        1: cab_dout <= { start_button[1], joystick2[6:0] };
        2: cab_dout <= { tilt, 4'hf, service, coin[1:0] };
        default: cab_dout <= 8'hff;
    endcase
end

jtframe_edge #(.QSET(0)) u_int(
    .rst    ( rst               ),
    .clk    ( clk               ),
    .edgeof ( ~LVBL & dip_pause ),
    .clr    ( ~VPAn             ),
    .q      ( intn              )
);

wire [7:2] nc;

jtframe_8bit_reg #(.XOR(8'b11)) u_out(
    .rst    ( rst                    ),
    .clk    ( clk                    ),
    .wr_n   ( LWRn                   ),
    .cs     ( out_cs                 ),
    .din    ( cpu_dout[7:0]          ),
    .dout   ( {nc,cchip_rst,syt_rst} )
);

jtframe_68kdtack_cen #(.W(6)) u_dtack(
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
    .num        ( 5'd1      ), // 16 MHz XTAL / 2 = 8 MHz, exactly 48/6
    .den        ( 6'd6      ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

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
    .HALTn      ( 1'b1        ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        )
);
`else
assign cpu_addr=0, cpu_dout=0, cpu_rnw=1, cpu_dsn=3, cpu_cen=0,
       rom_addr=0, ram_we=0, pal_we=0;
`ifdef RAM_IN_SDRAM
assign ram_dsn=3;
`endif
initial begin
    rom_cs=0; oram_cs=0; vdcm_cs=0; syt_cs=0; cchip_cs=0;
    ram_cs=0; pal_cs=0; dip_cs=0; in_cs=0;
end
`endif
endmodule
