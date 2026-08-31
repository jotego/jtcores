/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-8-2026 */

module jtsharrier_main #(
    // Master clock in kHz: JTFRAME_PLL=jtframe_pll6293 on MiSTer, the only target
    // built. A parameter, not a JTFRAME_MCLK read -- as s16 and outrun do MFREQ.
    parameter MCLK_KHZ = 50_347
)(
    input              rst,
    input              clk,
    output             cpu_cen,
    output             cpu_cenb,

    input              vint,

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

    output      [23:1] addr,
    output      [15:0] cpu_dout,
    output             RnW,
    output      [ 1:0] dsn,

    // Program ROM
    output reg         rom_cs,
    input       [15:0] rom_data,
    input              rom_ok,

    input       [ 7:0] dipsw_a,
    input       [ 7:0] dipsw_b,
    input              dip_test,
    input       [ 1:0] cab_1p,
    input       [ 1:0] coin,
    input              service,
    input       [ 8:0] joystick1,  // [6:4] fire buttons, [7] test, [8] service pads
    input       [ 7:0] an_x,       // flight stick, conditioned in game.v: ADC0 = X
    input       [ 7:0] an_y,       //                                      ADC1 = Y

    // Main PPI ports B and C, CPU sheet 2/6
    output             flip,
    output             sound_en,
    // Sound board interface via PPI0, sheet 2/6. Port A is MODE 1 strobed output:
    // a command write auto-asserts /OBF (port C bit 7), which is the Z80's NMI,
    // and /OBF releases only on /ACK (bit 6), here the Z80 reading the latch.
    // DO NOT tie portc_din[6] inactive -- that sends one NMI and then silence.
    output      [ 7:0] snd_latch,
    output             snd_nmin,
    output             snd_rstn,   // PPI0 port B bit 5, Z80 /RESET (active low)
    input              snd_ack,    // Z80 read the latch -> PPI0 port C bit 6, /ACK
    output             video_en,
    output             colscr_en,   // SCONT1: column-scroll enable to the tilemap
    output             rowscr_en,   // SCONT0: row-scroll enable to the tilemap

    // Sub PPI port A, CPU sheet 2/6
    output             sub_rstn,
    output             sub_intn,

    // i8751, CPU sheet 1/6
    input              mcu_cen,
    input      [ 8:0]  hdump,      // video H phase, for the VWAIT slot model
    input              mcu_we,
    input       [12:0] prog_addr,
    input       [ 7:0] prog_data,

    input       [ 7:0] st_addr,
    output reg  [ 7:0] st_dout
);

`ifndef NOMAIN

// XTAL1 on CPU sheet 1/6; the cen ratio follows JTFRAME_PLL.
// FDEN is 146, not 156: against pll6293's 50.347 MHz the latter rounds to
// 31/156 = 10.0049 MHz, 0.049% above the crystal. 29/146 lands on 10.0005.
localparam        CPU_KHZ  = 10_000;
localparam [ 7:0] FDEN     = 8'd146;
localparam [31:0] FNUM     = (CPU_KHZ*FDEN + MCLK_KHZ/2)/MCLK_KHZ;

wire [23:1] A, cpu_A;
wire [ 2:0] FC, IPLn;
wire        ASn, UDSn, LDSn, BUSn, VPAn, DTACKn;
wire        cpu_RnW, cpu_UDSn, cpu_LDSn;
wire        BRn, BGn, BGACKn;
wire [15:0] cpu_dout_raw;
reg  [15:0] cpu_din;
reg  [ 7:0] cab_dout, io_dout;
wire        rom_ok_dly, vram_ok_dly;
wire [ 7:0] ppi0_dout, ppi1_dout, ppi0_b, ppi0_c, ppi1_a;
wire [15:0] fave, fworst;

wire        inta_n = ~&{ FC, ~ASn };  // interrupt acknowledge

wire        mcu_bus, mcu_wr, mcu_acc;
wire [ 7:0] mcu_ctrl, mcu_dout;
wire [15:0] mcu_addr;
reg  [ 7:0] mcu_din;
reg         mcu_acc_l;
reg         mcu_ok, BGACKnl;
wire        mcu_gated;

// video_en is /KILL, active high for a live screen. SCONT0/1 are the tilemap
// scroll enables (sheet 2/6 to 2/7); PPI0 port C drives them active low, so they
// invert to the tilemap's active-high enables, matching jts16_main.
assign      video_en = ppi0_b[4];
wire [ 1:0] scont    = ppi0_c[2:1];   // {SCONT1, SCONT0}, active low
assign      colscr_en = ~scont[1];    // = ~ppi0_c[2]
assign      rowscr_en = ~scont[0];    // = ~ppi0_c[1]

// The MCU reaches the bus through the LS374 latches and the LS157 at IC23,
// sheet 1/6. P1 supplies the address bits above A15 and the interrupt level
// (MAME i8751_p1_w).
assign A        = mcu_bus ? { 3'd0, mcu_ctrl[6], 1'b0, mcu_ctrl[5:3],
                              mcu_addr[15:1] } : cpu_A;
assign RnW      = mcu_bus ? ~mcu_wr  : cpu_RnW;
// i8751_r/w reach the 68000 at (i8751_addr<<16)|(offset^1), so MCU offset 0 is
// an odd byte address and takes the lower lane.
assign UDSn     = mcu_bus ? ~mcu_addr[0] : cpu_UDSn;
assign LDSn     = mcu_bus ?  mcu_addr[0] : cpu_LDSn;
assign cpu_dout = mcu_bus ? {2{mcu_dout}} : cpu_dout_raw;

assign addr     = A;
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
assign BUSn     = (BGACKn & ASn) | (LDSn & UDSn);
// P1[2:0] is the interrupt level, driven by the MCU
assign IPLn     = mcu_ctrl[2:0];
assign VPAn     = inta_n;             // autovectored, CK-2605 315-5165

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
wire        bus_busy = (rom_cs & ~rom_ok_dly) | (vram_cs & ~vram_ok_dly) | vwait;

// bus_legit marks a stall the BOARD genuinely paid, so RECOVERY does not hand
// the cycles back. The two SDRAM waits are artifacts of this implementation --
// the PCB's ROM answers in one cycle, and xram only lives in SDRAM here -- so
// they are refunded. Only the VWAIT slot stall is real, so bus_legit is that
// term alone.
wire        bus_legit = vwait;

// jtframe_okdly gates each SDRAM ok by its cs, so a stale ok from the previous
// access cannot assert DTACKn before the new read completes (#1516).
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

// The decoder is CK-2605 315-5166, an undumped custom, so the region
// boundaries come from MAME's sharrier_map rather than from the sheet.
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
        if( mcu_bus ? mcu_acc : (!ASn && FC!=3'b111) ) begin
            // !BUSn qualifies vram_cs ONLY, as the SDRAM request handshake. It
            // carries the data strobes, so on a write it mistimes the write half
            // of a read-modify-write. DO NOT add it to a BRAM select -- that was
            // tried on hardware and reverted.
            rom_cs    <= A[23:18]==6'd0;             // 000000-03ffff
            ram_cs    <= A[23:14]==10'h010;          // 040000-043fff
            // Tile map RAM, read back from SDRAM xram by the TMG. The one
            // select that keeps !BUSn.
            vram_cs   <= A[23:15]==9'h020 && !BUSn;  // 100000-107fff, tileram
            // Text RAM plus the tile-map registers, a BRAM inside jts16_char
            char_cs   <= A[23:12]==12'h108;          // 108000-108fff, textram
            // 109000-10ffff is left undecoded: sharrier_map maps nothing there.
            objram_cs <= A[23:12]==12'h130;          // 130000-130fff
            // Palette RAM, a BRAM, so no !BUSn
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

// I/O sub-decode: A[5:4] picks the device, A[2:1] the register; A3 and above A5
// are mirrored (sharrier_map). Every register is on an odd byte address, so the
// devices see the low half of the bus. 140010 is the input mux, 140030 the ADC.
wire ppi0_cs = io_cs & (A[5:4]==2'd0);  // 140000, video_lamps_w, tilemap_sound_w
wire ppi1_cs = io_cs & (A[5:4]==2'd2);  // 140020, sub_control_adc_w
wire LDSWn   = RnW | LDSn;

// Port B is video_lamps_w, port C tilemap_sound_w. Bits not taken here: B[6]
// shadow, B[3:0] lamps and coin counters, C[6:3] the rest of the port-A mode 1
// handshake.
assign flip     =  ppi0_b[7];
assign sound_en =  ppi0_c[0];
assign snd_nmin =  ppi0_c[7];   // Z80 NMI, active low
// PPI0 port B D5 is the sound Z80's /RESET, active low (segahang.cpp:331).
// jt8255 resets latch_b to 8'hff, so the Z80 runs from power-up and stops only if
// the 68000 clears this bit to re-init a sound CPU that has lost latch sync.
assign snd_rstn =  ppi0_b[5];
// sub_control_adc_w: bit 5 is inverted with respect to bit 6, so a 1 holds the
// sub CPU in reset. The 8255 clears its output latches on a control-word write,
// which is what releases the sub at boot; the game never writes this port.
assign sub_rstn = ~ppi1_a[5];
assign sub_intn =  ppi1_a[6];

// Input multiplexer at 140010-140017: LS253 x4 (IC115-IC118) on sheet 2/6, a
// 4-select byte-wide mux driven by A[2:1]. Selection 0 reads the opto-isolated
// control inputs, 2/3 read DIP SW A/B, 1 reads back 0xff.
//
// Control inputs are active low, and so are jtframe's cabinet signals: feed them
// straight through. Inverting reads every input as held from boot.
//
// Bit order from MAME segahang.cpp INPUT_PORTS(sharrier), which sheet 2/6 does
// not legibly give. All active low:
//   0x01 COIN1  0x02 COIN2  0x04 SERVICE-MODE  0x08 SERVICE1
//   0x10 START1  0x20 BUTTON1  0x40 BUTTON2  0x80 BUTTON3
// Test and Service are also mappable to pad buttons; the AND lets either source
// pull the line low.
always @(*) begin
    case( A[2:1] )
        2'd0: cab_dout = { joystick1[6:4], cab_1p[0],
                           service & joystick1[8], dip_test & joystick1[7],
                           coin[1:0] };
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
// already conditioned in jtsharrier_game.v; a working board reads 0x80,0x80 at rest.
wire [1:0] adc_ch  = ppi1_a[3:2];
wire [7:0] adc_val = adc_ch[1] ? 8'h00 :    // channels 2,3: unpopulated
                     adc_ch[0] ? an_y :     // channel 1 = Y
                                 an_x;      // channel 0 = X
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
    // Port C bit 6 is /ACK for the mode 1 port A handshake, active low, driven
    // by the sound Z80's read of the command latch. jt8255 releases /OBF (bit 7,
    // the Z80's NMI) on the RISING edge of this, i.e. when the read completes.
    // Tying it high -- as this did until 2026-08-18 -- leaves /OBF stuck low
    // after the first command, so the Z80 receives one NMI and never another.
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

    // Port C reads back the ADC0804's /INTR on bit 6. The converter is not
    // implemented yet, so this reports a conversion that is always complete;
    // it is a stub and it is recorded as such in ISSUES.md.
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
    cpu_din <= rom_cs    ? rom_data              :
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
//
// The one-clock delay also buys margin: bus_busy does not cover wram, subram,
// pal, objram or I/O, which is where this MCU mostly goes, so without it the last
// mcu_din capture lands on the same clock BGACK is released. The MCU can reach
// textram (mcu_ctrl[6]=1, [5:3]=0 puts A at 0x108000), so it can take a VWAIT
// stall -- bounded by one slot, not a hang.
initial mcu_ok = 1;

always @(posedge clk) begin
    BGACKnl <= BGACKn;
    if( !mcu_cen ) mcu_ok <= rst | (BRn & BGACKn) | (BGACKnl ? 1'b0 : ~bus_busy);
end

assign mcu_gated = mcu_cen & mcu_ok;

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
    .rst        ( rst       ),
    .clk        ( clk       ),
    // XTAL2, 8 MHz on CPU sheet 1/6. Fed raw: jt8051 spends twelve `cen`
    // pulses on a machine cycle itself, so the DIVCEN divider the Oregano
    // core needed is gone. jts16_main.v dropped it the same way.
    .cen        ( mcu_gated ),

    .int0n      ( ~vint     ),
    .int1n      ( 1'b1      ),

    .p0_i       ( mcu_din   ),
    .p1_i       ( mcu_ctrl  ),   // read back so PUSH p1 behaves
    .p2_i       ( 8'hff     ),
    // vint must sit on P3.2, the INT0 pin: the 8051 core sources bit-addressed
    // P3 reads straight from p3_i, so a "jb int0" in the MCU ROM reads this
    // bit rather than the interrupt input. jts16_main.v does the same.
    // Nothing on this board drives INT1.
    .p3_i       ( { 5'h1f, ~vint, 2'b11 } ),

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

// fave/fworst are the measured cpu_cen frequency in kHz. They are how the
// running core reports its own CPU speed instead of it being inferred.
always @(posedge clk) begin
    case( st_addr[2:0] )
        3'd0: st_dout <= { 3'd0, io_cs, objram_cs, vram_cs, ram_cs, rom_cs };
        3'd1: st_dout <= { 2'd0, vint, mcu_bus, scont, sound_en, video_en };
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
    .bus_legit  ( bus_legit ),
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
