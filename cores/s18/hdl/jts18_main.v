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
    Date: 21-4-2024 */

module jts18_main(
    input              rst,
    input              clk,
    input              rst24,
    input              clk24,       // required to ease MCU synthesis
    input              pxl_cen,
    input              clk_rom,
    output             cpu_cen,
    input              mcu_cen,
    output             cpu_cenb,
    input  [7:0]       game_id,
    input              cab3,

    // video control
    input              vint,
    output             flip,
    output             gray_n,
    output             vdp_en,
    output             vid16_en,
    output      [ 7:0] tile_bank,
    output reg  [ 2:0] vdp_prio,

    // Video memory
    output reg         char_cs,
    output reg         pal_cs,
    output reg         objram_cs,
    output reg         bank_cs,
    input       [15:0] char_dout,
    input       [15:0] pal_dout,
    input       [15:0] obj_dout,
    input       [15:0] vdp_dout,
    input              vdp_dtackn,

    // RAM access
    output reg         vram_cs,
    input              vram_ok,
    input       [15:0] vram_data,
    output reg         ram_cs,
    input       [15:0] ram_data,
    // CPU bus
    output      [15:0] cpu_dout,
    output             UDSn,
    output             LDSn,
    output             RnW,
    output             ASn,
    output      [23:1] cpu_addr,

    // cabinet I/O
    input       [ 7:0] joystick1,
    input       [ 7:0] joystick2,
    input       [ 7:0] joystick3,
    input       [ 8:0] lg1_x,
    input       [ 8:0] lg1_y,
    input       [ 8:0] lg2_x,
    input       [ 8:0] lg2_y,
    input       [ 1:0] dial_x,
    input       [ 1:0] dial_y,
    input       [ 2:0] cab_1p,
    input       [ 2:0] coin,
    input              service,
    // ROM access
    output reg         rom_cs,
    output reg  [20:1] rom_addr,
    input       [15:0] rom_data,
    input              rom_ok,

    // PROM programming
    input       [12:0] prog_addr,
    input       [ 7:0] prog_data,
    // Decoder configuration
    input              fd1094_en,
    input              key_we,
    // MCU enable and ROM programming
    input              mcu_en,
    input              mcu_prog_we,

    // DIP switches
    input              dip_test,
    input       [15:0] dipsw,

    // Sound - Mapper interface
    input              sndmap_rd,
    input              sndmap_wr,
    input    [7:0]     sndmap_din,
    output   [7:0]     sndmap_dout,
    output             sndmap_pbf, // pbf signal == buffer full ?

    // status dump
    input       [ 7:0] debug_bus,
    input       [ 7:0] st_addr,
    output      [ 7:0] st_dout
);
`ifndef NOMAIN
//  Region 0 - Program ROM
//  Region 3 - 68000 work RAM
//  Region 4 - Object RAM
//  Region 5 - Text/tile RAM
//  Region 6 - Color RAM
//  Region 7 - I/O area
localparam [2:0] REG_RAM  = 3,
                 REG_ORAM = 4,
                 REG_VRAM = 5,
                 REG_PAL  = 6,
                 REG_IO   = 7;
localparam       PCB_5874 = 0,  // refers to the bit in game_id
                 PCB_5987_DESERTBR = 1,
                 PCB_5987 = 2,
                 PCB_7525 = 3,  // hamaway
                 PCB_5873 = 4,  // lghost
                 PCB_7248 = 5;  // shdancer


wire [23:1] A,cpu_A;
wire        BERRn;
wire [ 2:0] FC;
wire [ 7:0] st_mapper, st_timer, st_io, io_dout, io5296_dout, misc_o, key_data;
wire [12:0] key_addr;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

wire        BRn, BGACKn, BGn,
            BUSn, cpu_RnW, ok_dly, io_we, io_rd;
reg         sdram_ok, io_cs, vdp_cs;
wire [15:0] rom_dec, cpu_dout_raw;

wire [ 7:0] active, mcu_din, mcu_dout;
wire        mcu_wr, mcu_acc;
wire [15:0] mcu_addr;
wire [ 1:0] mcu_intn;
wire [ 2:0] cpu_ipln;
wire        DTACKn, cpu_vpan;

wire bus_cs    = pal_cs | char_cs | vram_cs | ram_cs | rom_cs | objram_cs | io_cs | vdp_cs;
wire bus_busy  = (|{ rom_cs, vram_cs } & ~sdram_ok) | (vdp_cs & vdp_dtackn);
wire cpu_rst, cpu_haltn, cpu_asn;
wire [ 1:0] cpu_dsn;
reg  [15:0] cpu_din;
wire [15:0] mapper_dout;
wire        none_cs;

reg   [7:0] p1, p2, p3, coinage;
wire        dial_cs;
wire        dial_rst;
wire  [7:0] dial_dout;
reg         mwalk, mwalka, ind_coin, play3;

assign BUSn    = LDSn & UDSn;
assign gray_n  = misc_o[6];
assign flip    = misc_o[5];
assign io_we   = io_cs && !RnW && !LDSn;
assign io_rd   = io_cs &&  RnW && !LDSn;
assign st_dout = st_io;
// No peripheral bus access for now
assign cpu_addr = A[23:1];
// assign BERRn = !(!ASn && BGACKn && !rom_cs && !char_cs && !objram_cs  && !pal_cs
//                               && !io_cs  && vram_cs && ram_cs);

always @( posedge clk ) begin
    mwalk    <= game_id[6];
    mwalka   <= game_id[7]; // In US version switches are exchanged
    ind_coin <= ~(dipsw[13]^mwalka) & mwalk;
    play3    <= ~(dipsw[12]^mwalka) & mwalk;
end

`ifndef NOMCU
jtframe_8751mcu #(
    .DIVCEN     ( 1             ),
    .SYNC_XDATA ( 1             ),
    .SYNC_P1    ( 1             ),
    .SYNC_INT   ( 1             ),
    .ROMBIN     ( "mcu"         )
) u_mcu(
    .rst        ( rst24         ),
    .clk        ( clk24         ),
    .cen        ( mcu_cen       ),

    .int0n      ( mcu_intn[0]   ),
    .int1n      ( mcu_intn[1]   ),

    .p0_i       ( mcu_din       ),
    .p1_i       ( coinage       ),
    .p2_i       ( 8'hff         ),
    .p3_i       ( 8'hff         ),

    .p0_o       (               ),
    .p1_o       (               ),
    .p2_o       (               ),
    .p3_o       (               ),

    // external memory
    .x_din      ( mcu_din       ),
    .x_dout     ( mcu_dout      ),
    .x_addr     ( mcu_addr      ),
    .x_wr       ( mcu_wr        ),
    .x_acc      ( mcu_acc       ),

    // ROM programming
    .clk_rom    ( clk_rom       ),
    .prog_addr  ( prog_addr[11:0] ),
    .prom_din   ( prog_data     ),
    .prom_we    ( mcu_prog_we   )
);
`else
assign mcu_dout = 0;
assign mcu_wr   = 0;
assign mcu_acc  = 0;
assign mcu_addr = 0;
`endif

// System 18 memory map
always @* begin
    rom_addr = A[20:1];
    if(active[0]) begin
        if(game_id[PCB_5874]|game_id[PCB_7248]) rom_addr[20:19]=0;
        if(game_id[PCB_7525]|game_id[PCB_5987]|game_id[PCB_5987_DESERTBR]) rom_addr[20]=0; // may need extra masking for smaller ROM sizes
    end
    // assuming that if active[1] is set, then A is already pointing after 512kB(or 1MB for Desert Breaker)
    if(active[1]) begin
        if(game_id[PCB_7525]|game_id[PCB_5873]|game_id[PCB_5987]) rom_addr[20:19]={1'b0, A[21]};
        if(game_id[PCB_5987_DESERTBR]) rom_addr[20]=A[21];
    end
end

always @* begin
    sdram_ok = ASn || (rom_cs ? ok_dly : vram_ok);
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
            rom_cs    <= 0;
            char_cs   <= 0; // 4 kB
            objram_cs <= 0; // 2 kB
            pal_cs    <= 0; // 4 kB
            io_cs     <= 0;
            vdp_cs    <= 0;

            vram_cs   <= 0; // 64kB
            ram_cs    <= 0; // 16kB
    end else begin
        if( !BUSn || (!ASn && RnW) /*&& BGACKn*/ ) begin
            rom_cs    <= (active[0] || (active[1] && !game_id[PCB_7248])) && RnW;
            vdp_cs    <= game_id[PCB_7248] ? active[1] : active[2];
            char_cs   <= active[REG_VRAM] && A[16];

            objram_cs <= active[REG_ORAM];
            pal_cs    <= active[REG_PAL];
            io_cs     <= active[REG_IO];

            // jtframe_ramrq requires cs to toggle to
            // process a new request. BUSn will toggle for
            // read-modify-writes
            vram_cs <= !BUSn && active[REG_VRAM] && !A[16];
            ram_cs  <= !BUSn && active[REG_RAM];
            bank_cs <= (game_id[PCB_7525]|game_id[PCB_5987]|game_id[PCB_5987_DESERTBR]) && active[1] && !RnW;
        end else begin
            rom_cs    <= 0;
            char_cs   <= 0;
            objram_cs <= 0;
            pal_cs    <= 0;
            io_cs     <= 0;
            vdp_cs    <= 0;
            vram_cs   <= 0;
            ram_cs    <= 0;
            bank_cs   <= 0;
        end
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vdp_prio <= 0;
    end else begin
        if( io_cs && !RnW && !LDSn && A[13] && !A[12] ) vdp_prio <= cpu_dout[2:0];
    end
end

// M6253 4 channel 8 bit ADC for LaserGhost
reg         m6253_shift_out;
reg   [7:0] m6253_shift_reg;
reg         io_rdl;

function [7:0] lg_xscale(input [8:0] x); // 0-319 -> 0-255
    reg [15:0] mult;
    begin
        mult = x * (16'd204 + (x<160 ? ({10'd0, x[8:3]}+{11'd0, x[8:4]}+{12'd0, x[8:5]}) : 16'd70-({10'd0, x[8:3]}+{11'd0, x[8:4]}+{12'd0, x[8:5]})));
        lg_xscale = mult[15:8];
    end
endfunction

always @(posedge clk) begin
    io_rdl <= io_rd;

    if (io_we && A[15:4] == 12'h301) begin
        case (A[2:1])
            0: m6253_shift_reg <= ~lg1_y[7:0];
            1: m6253_shift_reg <= lg_xscale(lg1_x);
            2: m6253_shift_reg <= ~lg2_y[7:0];
            3: m6253_shift_reg <= lg_xscale(lg2_x);
            default: ;
        endcase
    end
    if (io_rd && !io_rdl && A[15:4] == 12'h301) begin
        m6253_shift_out <= m6253_shift_reg[7];
        m6253_shift_reg <= { m6253_shift_reg[6:0], 1'b0 };
    end
end

// for wwally
assign dial_rst = io_we && A[15:3] == {12'h300, 1'd0};
assign dial_cs = io_cs & A[15:3] == {12'h300, 1'd0}; // only one trackball

jt4701 u_trackball(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .x_in   ( {dial_x[0], dial_x[1]} ),
    .y_in   ( {dial_y[0], dial_y[1]} ),
    .rightn (           ),
    .leftn  (           ),
    .middlen(           ),
    .x_rst  (dial_rst   ),
    .y_rst  (dial_rst   ),
    .csn    ( ~dial_cs  ),
    .uln    ( A[1]      ),
    .xn_y   ( A[2]      ),
    .cfn    (           ),
    .sfn    (           ),
    .dout   ( dial_dout ),
    .dir    (           )
);

assign io_dout = (A[15:4] == 12'h301) ? {m6253_shift_out, 7'h7f} :
                              dial_cs ? dial_dout :
                                        io5296_dout;

always @(*) begin
    if (game_id[PCB_5873]) begin
        p1 = {joystick3[4], joystick3[5], 2'b11, joystick2[5:4], joystick1[5:4]};
        p2 = 8'hff;
        p3 = 8'hff;
        coinage = { coin[2], 2'b11, service, 1'b1, dip_test, coin[1:0] };
    end else begin
        p1 = {joystick1[3:0],joystick1[7:4]};
        p2 = {joystick2[3:0],joystick2[7:4]};
        p3 = {joystick3[3:0],joystick3[7:4]};
        // MSB 7-6 are select inputs, used in Wally
        // It may be safe to connect to button 0
        coinage = cab3 || ( play3 && ind_coin ) ?
            { coin[0], cab_1p[2:0], service, dip_test, coin[1], coin[2] }:
            {   2'b11, cab_1p[1:0], service, dip_test, coin[1:0] };
        if( mwalk ) begin
            p3[3]      = cab_1p[2];
            coinage[6] = 1'b1;
            if( !play3 ) coinage[1:0] = {coin[0],coin[1]};
        end
    end
end

jts18_io u_ioctl(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .addr       ( {A[13],A[5:1]}),
    .din        ( cpu_dout[7:0] ),
    .dout       ( io5296_dout   ),
    .we         ( io_we         ),
    // eight 8-bit ports
    .pa_i       ( p1            ),
    .pb_i       ( p2            ),
    .pc_i       ( p3            ),
    .pd_o       ( misc_o        ),
    .pe_i       ( coinage       ),
    .ph_o       ( tile_bank     ),
    .pf_i       ( dipsw[ 7:0]   ),
    .pg_i       ( dipsw[15:8]   ),
    // unused
    .pa_o       (               ),
    .pb_o       (               ),
    .pc_o       (               ),
    .pd_i       ( 8'd0          ),
    .pe_o       (               ),
    .pf_o       (               ),
    .pg_o       (               ),
    .ph_i       ( 8'd0          ),
    // three output pins
    .aux0       (               ),
    .aux1       ( vid16_en      ),
    .aux2       ( vdp_en        ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_io         )
);

// Data bus input
always @(posedge clk) begin
    if(rst) begin
        cpu_din <= 0;
    end else begin
        cpu_din <=  ram_cs             ? ram_data  :
                    vram_cs            ? vram_data :
                    rom_cs             ? rom_dec   :
                    char_cs            ? char_dout :
                    pal_cs             ? pal_dout  :
                    objram_cs          ? obj_dout  :
                    io_cs              ? {8'hff,io_dout} :
                    vdp_cs             ? vdp_dout    :
                    none_cs            ? mapper_dout :
                                         16'hffff;
    end
end
/* verilator tracing_on */
jts16_fd1094 #(.SIMFILE("maincpu:key")) u_dec1094(
    .rst        ( cpu_rst   ),
    .clk        ( clk       ),

    // Configuration
    .prog_addr  ( prog_addr ),
    .fd1094_we  ( key_we    ),
    .prog_data  ( prog_data ),

    // Key access
    .key_addr   ( key_addr  ),
    .key_data   ( key_data  ),

    // Operation
    .dec_en     ( fd1094_en ),
    .FC         ( FC        ),
    .ASn        ( ASn       ),

    .addr       ( A         ),
    .enc        ( rom_data  ),
    .dec        ( rom_dec   ),

    .dtackn     ( DTACKn    ),
    .rom_ok     ( rom_ok    ),
    .ok_dly     ( ok_dly    )
);

jtframe_prom #(.AW(13),.SIMFILE("maincpu:key")) u_key(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( prog_data ),
    .rd_addr( key_addr  ),
    .wr_addr( prog_addr[12:0] ),
    .we     ( key_we    ),
    .q      ( key_data  )
);
/* verilator tracing_on */
jts16b_mapper #(.FNUM(7'd5),.FDEN(8'd24)) u_mapper(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .pxl_cen    ( pxl_cen        ),
    .cpu_cen    ( cpu_cen        ),
    .cpu_cenb   ( cpu_cenb       ),
    .vint       ( vint           ),

    .addr       ( cpu_A          ),
    .cpu_dout   ( cpu_dout_raw   ),
    .cpu_dsn    ( cpu_dsn        ),
    .bus_dsn    ( {UDSn,  LDSn}  ),
    .bus_cs     ( bus_cs         ),
    .bus_busy   ( bus_busy       ),
    // effective bus signals
    .addr_out   ( A              ),

    .none       ( none_cs        ),
    .mapper_dout( mapper_dout    ),

    // Bus sharing
    .bus_dout   ( cpu_din        ),
    .bus_din    ( cpu_dout       ),
    .cpu_rnw    ( cpu_RnW        ),
    .bus_rnw    ( RnW            ),
    .bus_asn    ( ASn            ),

    // M68000 control
    .cpu_berrn  ( BERRn          ),
    .cpu_brn    ( BRn            ),
    .cpu_bgn    ( BGn            ),
    .cpu_bgackn ( BGACKn         ),
    .cpu_dtackn ( DTACKn         ),
    .cpu_asn    ( cpu_asn        ),
    .cpu_fc     ( FC             ),
    .cpu_ipln   ( cpu_ipln       ),
    .cpu_vpan   ( cpu_vpan       ),
    .cpu_haltn  ( cpu_haltn      ),
    .cpu_rst    ( cpu_rst        ),

    // Sound CPU
    .sndmap_rd  ( sndmap_rd      ),
    .sndmap_wr  ( sndmap_wr      ),
    .sndmap_din ( sndmap_din     ),
    .sndmap_dout( sndmap_dout    ),
    .sndmap_pbf ( sndmap_pbf     ),

    // MCU side
    .mcu_en     ( mcu_en         ),
    .mcu_dout   ( mcu_dout       ),
    .mcu_din    ( mcu_din        ),
    .mcu_intn   ( mcu_intn       ),
    .mcu_addr   ( mcu_addr       ),
    .mcu_wr     ( mcu_wr         ),
    .mcu_acc    ( mcu_acc        ),

    .active     ( active         ),
    .debug_bus  ( debug_bus      ),
  //.debug_bus  ( 8'd0           ),
    .st_addr    ( st_addr        ),
    .st_dout    ( st_mapper      )
);
/* xxverilator tracing_off */
jtframe_m68k u_cpu(
    .RESETn     (             ),
    .clk        ( clk         ),
    .rst        ( cpu_rst     ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

    // Buses
    .eab        ( cpu_A       ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout_raw),


    .eRWn       ( cpu_RnW     ),
    .LDSn       ( cpu_dsn[0]  ),
    .UDSn       ( cpu_dsn[1]  ),
    .ASn        ( cpu_asn     ),
    .VPAn       ( cpu_vpan    ),
    .FC         ( FC          ),

    .BERRn      ( BERRn       ),
    // Bus arbitrion
    .HALTn      ( cpu_haltn   ),
    .BRn        ( BRn         ),
    .BGACKn     ( BGACKn      ),
    .BGn        ( BGn         ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( cpu_ipln    ) // VBLANK
);
`else
    initial char_cs     = 0;
    initial pal_cs      = 0;
    initial objram_cs   = 0;
    initial ram_cs      = 0;
    initial vram_cs     = 0;
    initial rom_cs      = 0;
    initial rom_addr    = 0;
    assign  cpu_cen     = 0;
    assign  cpu_cenb    = 0;
    assign  flip        = 0;
    assign  gray_n      = 0;
    assign  vdp_en      = 0;
    assign  vid16_en    = 0;
    assign  tile_bank   = 0;
    assign  cpu_dout    = 0;
    assign  UDSn        = 0;
    assign  LDSn        = 0;
    assign  RnW         = 0;
    assign  ASn         = 0;
    assign  cpu_addr    = 0;
    assign  sndmap_dout = 0;
    assign  sndmap_pbf  = 0;
    assign  st_dout     = 0;
`endif
endmodule
