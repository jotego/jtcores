/* SPDX-FileCopyrightText: 2026 Chris Watson/Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-8-2026 */

module jtharier_main(
    input              rst,
    input              clk,
    input              i8751,
    input              fd1089,
    input              blank4,
    input              cab1p,
    input       [ 2:0] adc,
    output      [12:0] key_addr,
    input       [ 7:0] key_data,
    input              fd1089_we,
    output             cpu_cen,
    output             cpu_cenb,

    input              LVBL, cen_mcu,

    // Address decode, CK-2605 315-5166 on CPU sheet 1/6
    output reg         vram_cs,
    output reg         char_cs,
    output reg         objram_cs,
    output reg         pal_cs,
    output reg         subram_cs,
    output reg         roadram_cs,
    output reg         io_cs,
    input       [15:0] vram_data,
    input              vram_ok,
    input       [15:0] char_dout,
    input       [15:0] objram_dout,
    input       [15:0] pal_dout,
    input       [15:0] subram_dout,

    // Work RAM, IC96/IC83 on CPU sheet 1/6
    output reg         ram_cs,
    input       [15:0] ram_dout,

    output      [17:1] addr,
    output      [15:0] cpu_dout,
    output             RnW,
    output      [ 1:0] dsn,

    // Program ROM
    output reg         rom_cs,
    input       [15:0] rom_data,
    input              rom_ok,

    input       [ 7:0] dipsw_a,
    input       [ 7:0] dipsw_b,
    input              dip_test, dip_pause,
    input       [ 1:0] cab_1p,
    input       [ 1:0] coin,
    input              service,
    input       [ 6:0] joystick1,
    input       [ 7:0] an_x,       // flight stick, conditioned in game.v: ADC0 = X
    input       [ 7:0] an_y,       //                                      ADC1 = Y
    input       [ 7:0] an_gas,
    input       [ 7:0] an_brake,

    output             flip,
    output reg         mute,
    output             video_en,
    output             colscr_en,   // SCONT1: column-scroll enable to the tilemap
    output             rowscr_en,   // SCONT0: row-scroll enable to the tilemap
    // sound
    output      [ 7:0] snd_latch,
    output             snd_nmin,
    output             snd_rstn,   // PPI0 port B bit 5, Z80 /RESET (active low)
    input              snd_ack,    // Z80 read the latch -> PPI0 port C bit 6, /ACK

    // Sub PPI port A, CPU sheet 2/6
    output             sub_rstn,
    output             sub_intn,

    // i8751, CPU sheet 1/6
    input      [ 8:0]  hdump,      // video H phase, for the VWAIT slot model
    input              mcu_we,
    input       [12:0] prog_addr,
    input       [ 7:0] prog_data,

    input       [ 7:0] st_addr,
    output reg  [ 7:0] st_dout
);
`ifndef NOMAIN
wire [23:1] A, cpu_A;
wire [ 2:0] FC, IPLn;
wire        ASn, UDSn, LDSn, VPAn, DTACKn;
wire        cpu_RnW, cpu_UDSn, cpu_LDSn;
wire        BRn, BGn, BGACKn;
wire [15:0] cpu_dout_raw;
reg  [15:0] cpu_din;
reg  [ 7:0] cab_dout, io_dout;
wire        rom_ok_dly, vram_ok_dly, sound_en, fd1089_ok;
wire [15:0] fd1089_dec;
wire [15:0] rom_dec = fd1089 ? fd1089_dec : rom_data;
wire [ 7:0] ppi0_dout, ppi1_dout, ppi0_b, ppi0_c, ppi1_a;
wire [15:0] fave, fworst;
wire        lvbl_g, op_n;
wire        inta_n = ~&{ FC, ~ASn };  // interrupt acknowledge

wire        mcu_bus, mcu_wr, mcu_acc;
wire [ 7:0] mcu_ctrl, mcu_dout;
wire [15:0] mcu_addr;
reg  [ 7:0] mcu_din;
reg         mcu_acc_l;
reg         mcu_ok, BGACKnl;
reg         vbl_irqn, lvbl_l;
wire        mcu_gated;
reg         mcu_rst, fd1089_rst;

assign      lvbl_g   = dip_pause ? LVBL : 1'b1;
assign      video_en = ppi0_b[4];
wire [ 1:0] scont    = ppi0_c[2:1];   // {SCONT1, SCONT0}, active low
assign      colscr_en = ~scont[1];    // = ~ppi0_c[2]
assign      rowscr_en = ~scont[0];    // = ~ppi0_c[1]
assign A        = mcu_bus ? { 3'd0, mcu_ctrl[6], 1'b0, mcu_ctrl[5:3],
                              mcu_addr[15:1] } : cpu_A;
assign RnW      = mcu_bus ? ~mcu_wr  : cpu_RnW;
assign UDSn     = mcu_bus ? ~mcu_addr[0] : cpu_UDSn;
assign LDSn     = mcu_bus ?  mcu_addr[0] : cpu_LDSn;
assign cpu_dout = mcu_bus ? {2{mcu_dout}} : cpu_dout_raw;
assign addr     = A[17:1];
assign op_n     = FC[1:0] != 2'b10; // low for CPU instruction fetches
assign flip     = ppi0_b[7];
assign sound_en = ppi0_c[0];
assign snd_nmin = ppi0_c[7];
assign snd_rstn = ppi0_b[5];
assign sub_rstn =~ppi1_a[5];
assign sub_intn = ppi1_a[6];

always @(posedge clk) begin
    mcu_rst    <= rst | ~i8751;
    fd1089_rst <= rst | ~fd1089;
end

always @(posedge clk) begin
    if( rst ) begin
        vbl_irqn <= 1;
        lvbl_l   <= 1;
    end else begin
        lvbl_l <= lvbl_g;
        if( !inta_n )
            vbl_irqn <= 1;
        else if( !lvbl_g && lvbl_l )
            vbl_irqn <= 0;
    end
end

// Block the MCU's write to the main/MCU sync byte at 0x040385, as MAME does
// unconditionally (segahang.cpp i8751_w: "the cpu is too fast or the mcu too
// slow ... the mcu clears this value after the cpu sets it"). If the clear lands,
// an MCU retry counter expires and the whole ADC scan is skipped -- service mode
// then shows frozen Control Lever values and the stick is dead.
wire mcu_syncw  = mcu_bus & mcu_wr & A[23:16]==8'h04 & mcu_addr==16'h0384;
// WRITE strobes, RnW-qualified, not the raw {UDSn,LDSn}: jts16_char derives its
// write enable from these alone, so raw strobes make every CPU READ of char RAM
// write over the location being read. jts16_main qualifies at the source too.
assign dsn      = { RnW | UDSn | mcu_syncw, RnW | LDSn | mcu_syncw };
assign IPLn     = { blank4 ? vbl_irqn : mcu_ctrl[2], mcu_ctrl[1:0] };
assign VPAn     = inta_n;

wire        bus_cs   = rom_cs | ram_cs | vram_cs | char_cs | objram_cs | pal_cs |
                       subram_cs | roadram_cs | io_cs;
// VWAIT: the board stalls the main CPU off video RAM until the video's fetch
// phase for the layer it is addressing reaches the CPU's slot. IC106 (CK-2605
// 315-5168, control sheet 1/7) decides it from /VRAM, AD1, AD15, H3, HA3, HB3 and
// /HSYNC -- no vertical input, so it applies to every VRAM access all frame long.
// IC145 splits /SLWR from /FLWR on AD15 and uses only the A=0 outputs, so a write
// strobe is produced only while VWT is low: VWT is the grant, VWAIT the hold.
//
// AD15 is why this covers both selects: tileram 100000-107fff, textram
// 108000-108fff.
//
// The PAL is undumped, so three things are not readable from it. The period is
// 8 or 16 off H3; both were built and 16 was falsified on the cabinet. The layer
// slots are assumed half a period apart, and the slot one pixel wide.
//
// char_cs asserts at S2 from !ASn while vram_cs waits for !BUSn at S4 on a write,
// so the slot hunt opens ~1 CPU clock earlier for textram. Forcing them to agree
// would delay the stall past DTACK and lose it entirely.
localparam [ 2:0] VWPHASE_SCR = 3'd0;  // HA3's phase -- tileram / scroll layer
localparam [ 2:0] VWPHASE_FIX = 3'd4;  // HB3's, half a period away -- textram / fix

wire        vram_acc  = vram_cs | char_cs;
// AD15 selects which layer's phase applies, exactly as IC145 uses it downstream.
wire        vw_slot   = hdump[2:0] == (vram_cs ? VWPHASE_SCR : VWPHASE_FIX);
reg         vw_grant;

// Latch the grant for one access. Without it vwait re-asserts at every non-slot
// pixel of a long access, holding bus_legit high across the SDRAM tail and
// suppressing the RECOVERY refund those waits are supposed to get.
always @(posedge clk) begin
    if( rst ) vw_grant <= 0;
    else if( !vram_acc ) vw_grant <= 0;
    else if(  vw_slot  ) vw_grant <= 1;
end

wire        vwait    = vram_acc & ~vw_grant;
wire        bus_busy = (rom_cs & ~(fd1089 ? fd1089_ok : rom_ok_dly)) |
                       (vram_cs & ~vram_ok_dly) | vwait;

jtframe_okdly u_rom_okdly(
    .rst    ( rst        ),
    .clk    ( clk        ),
    .cs     ( rom_cs     ),
    .ok     ( rom_ok     ),
    .ok_dly ( rom_ok_dly )
);

jtframe_okdly u_vram_okdly(
    .rst    ( rst         ),
    .clk    ( clk         ),
    .cs     ( vram_cs     ),
    .ok     ( vram_ok     ),
    .ok_dly ( vram_ok_dly )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_cs     <= 0;
        ram_cs     <= 0;
        vram_cs    <= 0;
        char_cs    <= 0;
        objram_cs  <= 0;
        pal_cs     <= 0;
        subram_cs  <= 0;
        roadram_cs <= 0;
        io_cs      <= 0;
    end else begin
        if( mcu_bus ? mcu_acc : (!ASn && FC!=3'b111 && {UDSn,LDSn}!=2'b11) ) begin
            rom_cs    <= A[23:18]==6'd0;             // 000000-03ffff
            ram_cs    <= A[23:14]==10'h010;          // 040000-043fff
            vram_cs   <= A[23:15]==9'h020;           // 100000-107fff, tileram
            // Text RAM plus the tile-map registers, a BRAM inside jts16_char
            char_cs   <= A[23:12]==12'h108;          // 108000-108fff, textram
            // 109000-10ffff is left undecoded: sharrier_map maps nothing there.
            objram_cs <= A[23:12]==12'h130;          // 130000-130fff
            pal_cs    <= A[23:12]==12'h110;          // 110000-110fff
            io_cs     <= A[23:16]==8'h14;            // 140000-14ffff, mirrored
            subram_cs <= A[23:16]==8'h12 && A[15:14]==2'b01; // 124000-127fff
            roadram_cs<= A[23:12]==12'hc68;          // c68000-c68fff
        end else begin
            rom_cs     <= 0;
            ram_cs     <= 0;
            vram_cs    <= 0;
            char_cs    <= 0;
            objram_cs  <= 0;
            pal_cs     <= 0;
            subram_cs  <= 0;
            roadram_cs <= 0;
            io_cs      <= 0;
        end
    end
end

wire ppi0_cs = io_cs & (A[5:4]==2'd0);  // 140000, video_lamps_w, tilemap_sound_w
wire ppi1_cs = io_cs & (A[5:4]==2'd2);  // 140020, sub_control_adc_w
wire LDSWn   = RnW | LDSn;

always @(*) begin
    case( A[2:1] )
        2'd0: cab_dout = { cab1p ? { 1'b1, cab_1p[0], 2'b11 } : { joystick1[6:4], cab_1p[0] },
                           service, dip_test, coin[1:0] };
        2'd1: cab_dout = 8'hff;
        2'd2: cab_dout = dipsw_a;
        2'd3: cab_dout = dipsw_b;
    endcase
end

// Flight-stick ADC at 140030, sheet 2/6: IC126 ADC0804 behind the IC125 CD4051
// mux, channel select from PPI1 port A[3:2], /INTR returned on PPI1 port C bit 6.
// ADC0 is stick X and ADC1 stick Y, both centred at 0x80 (segahang.cpp:915).
// The unpopulated CD4051 inputs read back 0x00, not open bus. The MCU scans six
// times per vblank into 0x40492..0x40497 and the game consumes that, so a wrong
// value here is a real divergence rather than just a dead stick. The axes arrive
// already conditioned in jtharier_game.v; a working board reads 0x80,0x80 at rest.
wire [1:0] adc_ch  = ppi1_a[3:2];
reg  [7:0] adc_val;
always @(*) begin
    if( adc==3'd4 )
        case( adc_ch )
            2'd0: adc_val = an_gas;
            2'd1: adc_val = an_brake;
            2'd2: adc_val = an_y;     // bank up/down
            2'd3: adc_val = an_x;     // steering, reversed in jtharier_cab
        endcase
    else
        case( adc_ch )
            2'd0: adc_val = an_x;
            2'd1: adc_val = an_y;
            default: adc_val = 8'h00;
        endcase
end
always @(*) begin
    case( A[5:4] )
        2'd0:    io_dout = ppi0_dout;
        2'd1:    io_dout = cab_dout;
        2'd2:    io_dout = ppi1_dout;
        default: io_dout = adc_val;         // 140030, ADC0804
    endcase
end

jt8255 u_ppi0(
    .rst       ( rst           ),
    .clk       ( clk           ),

    .addr      ( A[2:1]        ),
    .din       ( cpu_dout[7:0] ),
    .dout      ( ppi0_dout     ),
    .rdn       ( ~RnW          ),
    .wrn       ( LDSWn         ),
    .csn       ( ~ppi0_cs      ),

    .porta_din ( 8'hff         ),
    .portb_din ( 8'hff         ),
    .portc_din ( { 1'b1, ~snd_ack, 6'h3f } ),

    .porta_dout( snd_latch     ),
    .portb_dout( ppi0_b        ),
    .portc_dout( ppi0_c        )
);

jt8255 u_ppi1(
    .rst       ( rst           ),
    .clk       ( clk           ),

    .addr      ( A[2:1]        ),
    .din       ( cpu_dout[7:0] ),
    .dout      ( ppi1_dout     ),
    .rdn       ( ~RnW          ),
    .wrn       ( LDSWn         ),
    .csn       ( ~ppi1_cs      ),

    .porta_din ( 8'hff         ),
    .portb_din ( 8'hff         ),
    .portc_din ( 8'h00         ),

    .porta_dout( ppi1_a        ),
    .portb_dout(               ),
    .portc_dout(               )
);

// Hold the MOVX byte until the next MCU bus cycle: jtframe_8751mcu samples x_din
// through a two-stage pipe when SYNC_XDATA is set, so it must stay put for two
// MCU cen periods after the access. Capturing on every clock would track the main
// CPU's own reads once BGACK released.
always @(posedge clk) begin
    mcu_acc_l <= mcu_acc;
    if( mcu_bus && mcu_acc_l )
        mcu_din <= mcu_addr[0] ? cpu_din[15:8] : cpu_din[7:0];
end

always @(posedge clk) begin
    cpu_din <= rom_cs    ? rom_dec               :
               ram_cs    ? ram_dout              :
               vram_cs   ? vram_data             :
               char_cs   ? char_dout             :
               objram_cs ? objram_dout           :
               pal_cs    ? pal_dout              :
               subram_cs ? subram_dout           :
               io_cs     ? { 8'hff, io_dout }    : 16'hffff;
end

assign mcu_bus = ~BGACKn;

// The MCU must not advance while an access of its own is outstanding, or it sees
// zero-latency memory and runs ahead of the bus. The board does this with the
// BREQ/BACK handshake at IC23/IC8/IC9 (sheet 1/6); jts16_main models the S16A
// equivalent, its IC69 82S153. Idles permissive: with no request outstanding the
// MCU runs freely.
//
// BGACKn delayed one clock gives the three states needed: run when idle, HOLD
// while a request is outstanding but ungranted, then gate on the bus once
// granted. The hold is load-bearing -- jt8051 asserts x_acc for a single
// microcode step, not for the whole machine cycle, and jtframe_68kdma frees the
// bus as soon as dev_br drops, so an ungated MCU walks past its own request
// before the 68000 grants it and the access never happens. Freezing cen holds the
// microstep, which holds x_acc, which holds the request.
initial mcu_ok = 1;

always @(posedge clk) begin
    mute <= ~sound_en;
    BGACKnl <= BGACKn;
    if( !cen_mcu ) mcu_ok <= rst | (BRn & BGACKn) | (BGACKnl ? 1'b0 : ~bus_busy);
end

assign mcu_gated = cen_mcu & mcu_ok;

jtframe_68kdma u_dma(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cpu_cen   ),
    .cpu_BRn    ( BRn       ),
    .cpu_BGACKn ( BGACKn    ),
    .cpu_BGn    ( BGn       ),
    .cpu_ASn    ( ASn       ),
    .cpu_DTACKn ( DTACKn    ),
    .dev_br     ( mcu_acc   )
);

jtframe_8751mcu #(
    .SYNC_XDATA ( 1         ),
    .SYNC_P1    ( 1         ),
    .SYNC_INT   ( 1         ),
    .ROMBIN     ( "mcu.bin" )
) u_mcu(
    .rst        ( mcu_rst   ),
    .clk        ( clk       ),
    .cen        ( mcu_gated ),

    .int0n      ( lvbl_g    ),
    .int1n      ( 1'b1      ),

    .p0_i       ( mcu_din   ),
    .p1_i       ( mcu_ctrl  ),   // read back so PUSH p1 behaves
    .p2_i       ( 8'hff     ),
    .p3_i       ( 8'hff     ),

    .p0_o       (           ),
    .p1_o       ( mcu_ctrl  ),
    .p2_o       (           ),
    .p3_o       (           ),

    .x_din      ( mcu_din   ),
    .x_dout     ( mcu_dout  ),
    .x_addr     ( mcu_addr  ),
    .x_wr       ( mcu_wr    ),
    .x_acc      ( mcu_acc   ),

    .clk_rom    ( clk       ),
    .prog_addr  ( prog_addr[11:0] ),
    .prom_din   ( prog_data ),
    .prom_we    ( mcu_we    )
);

jts16_fd1089 u_fd1089(
    .rst        ( fd1089_rst    ),
    .clk        ( clk           ),

    .key_addr   ( key_addr      ),
    .key_data   ( key_data      ),

    .prog_addr  ( prog_addr     ),
    .fd1089_we  ( fd1089_we     ),
    .prog_data  ( prog_data     ),

    .dec_type   ( 1'b1          ),
    .dec_en     ( fd1089        ),
    .op_n       ( op_n          ),
    .addr       ( A             ),
    .enc        ( rom_data      ),
    .dec        ( fd1089_dec    ),

    .rom_ok     ( rom_ok        ),
    .ok_dly     ( fd1089_ok     )
);

always @(posedge clk) begin
    case( st_addr[1:0] )
        2'b10: st_dout <= fave[ 7:0];
        2'b11: st_dout <= fave[15:8];
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
    .bus_legit  ( vwait     ),
    .bus_ack    (~BGACKn    ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .DTACKn     ( DTACKn    ),
    .fave       ( fave      ),
    .fworst     ( fworst    )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

    .eab        ( cpu_A       ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout_raw),

    .eRWn       ( cpu_RnW     ),
    .LDSn       ( cpu_LDSn    ),
    .UDSn       ( cpu_UDSn    ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),

    .BERRn      ( 1'b1        ),
    .HALTn      ( 1'b1        ),
    .BRn        ( BRn         ),
    .BGACKn     ( BGACKn      ),
    .BGn        ( BGn         ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        )
);

`else

initial begin
    rom_cs     = 0;
    ram_cs     = 0;
    vram_cs    = 0;
    char_cs    = 0;
    objram_cs  = 0;
    pal_cs     = 0;
    subram_cs  = 0;
    roadram_cs = 0;
    io_cs      = 0;
    st_dout   = 0;
end

assign flip     = 0;
assign sound_en = 1;
assign snd_latch= 0;
assign snd_nmin = 1;
assign snd_rstn = 1;
assign sub_rstn = 0;
assign sub_intn = 1;
assign addr     = 0;
assign cpu_dout = 0;
assign RnW      = 1;
assign dsn      = 3;
assign cpu_cen  = 0;
assign cpu_cenb = 0;
assign video_en = 1;   // unblanked: x here reaches colmix's /KILL latch
assign colscr_en= 0;
assign rowscr_en= 0;

`endif

endmodule
